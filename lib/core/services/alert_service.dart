import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../constants/app_constants.dart';
import 'firebase_service.dart';
import 'global_alert_cache_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ALERT STATE MACHINE
// ═══════════════════════════════════════════════════════════════════════════

/// Three-state machine for each alert condition
enum AlertPhase {
  /// No issue detected — baseline state
  normal,

  /// Condition is starting — not yet confirmed
  warning,

  /// Alert confirmed and fired
  critical,
}

/// Tracks the phase + timing of a single alert condition
class _AlertCondition {
  AlertPhase phase = AlertPhase.normal;

  /// How many consecutive sensor readings have held the condition
  int consecutiveReadings = 0;

  /// When the condition first became true in this streak
  DateTime? conditionStartTime;

  /// When the alert was last fired to Firestore (for debounce)
  DateTime? lastFiredTime;

  /// When the condition first returned to normal (for cooldown)
  DateTime? normalSinceTime;

  /// Whether a Firestore alert document was created in this cycle
  bool alertFired = false;

  void reset() {
    phase = AlertPhase.normal;
    consecutiveReadings = 0;
    conditionStartTime = null;
    normalSinceTime = null;
    alertFired = false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALERT SERVICE — Smart, Debounced, State-Machine-Based Alert Engine
// ═══════════════════════════════════════════════════════════════════════════

class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  StreamSubscription<DatabaseEvent>? _sensorSub;
  Timer? _evaluationTimer;

  String? _elderlyUid;
  String? _elderlyName;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  SensorData _lastData = SensorData.empty;
  SensorData get lastData => _lastData;

  DateTime? _lastMotionTime;

  // ── Alert conditions ────────────────────────────────────────────
  final _AlertCondition _fallCondition = _AlertCondition();
  final _AlertCondition _inactivityCondition = _AlertCondition();

  // ── Current overall state (exposed for UI) ──────────────────────
  AlertPhase _overallPhase = AlertPhase.normal;
  AlertPhase get overallPhase => _overallPhase;

  String _smartMessage = 'Initializing monitoring...';
  String get smartMessage => _smartMessage;

  // ── Callbacks ───────────────────────────────────────────────────
  void Function(SensorData data)? onSensorUpdate;
  void Function(String alertType, AlertPhase phase)? onAlertPhaseChanged;

  // ═════════════════════════════════════════════════════════════════
  // START / STOP
  // ═════════════════════════════════════════════════════════════════

  void startMonitoring({
    required String elderlyUid,
    required String elderlyName,
  }) {
    if (_isMonitoring) stopMonitoring();

    _elderlyUid = elderlyUid;
    _elderlyName = elderlyName;
    _isMonitoring = true;
    _lastMotionTime = DateTime.now();
    _fallCondition.reset();
    _inactivityCondition.reset();
    _overallPhase = AlertPhase.normal;

    // Listen to real-time sensor stream
    _sensorSub = FirebaseService.instance.sensorStream().listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) return;

        final map = Map<String, dynamic>.from(data as Map);
        final sensorData = SensorData.fromMap(map);

        _lastData = sensorData;
        onSensorUpdate?.call(sensorData);

        // Track last motion time
        if (sensorData.motion || sensorData.presence) {
          _lastMotionTime = DateTime.now();
        }
      },
      onError: (error) {
        debugPrint('AlertService sensor error: $error');
      },
    );

    // Periodic evaluation at fixed intervals (not on every sensor reading)
    _evaluationTimer = Timer.periodic(
      Duration(seconds: AppConstants.sensorCheckIntervalSeconds),
      (_) => _evaluate(),
    );
  }

  void stopMonitoring() {
    _sensorSub?.cancel();
    _sensorSub = null;
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    _isMonitoring = false;
    _elderlyUid = null;
    _elderlyName = null;
    _fallCondition.reset();
    _inactivityCondition.reset();
    _overallPhase = AlertPhase.normal;
  }

  // ═════════════════════════════════════════════════════════════════
  // MAIN EVALUATION — runs every N seconds (not on every reading)
  // ═════════════════════════════════════════════════════════════════

  void _evaluate() {
    if (!_isMonitoring) return;

    _evaluateFall(_lastData);
    _evaluateInactivity();
    _updateOverallState();
    _updateSmartMessage();
  }

  // ═════════════════════════════════════════════════════════════════
  // FALL DETECTION — with confirmation + cooldown
  // ═════════════════════════════════════════════════════════════════

  void _evaluateFall(SensorData data) {
    final isFallNow = data.isEmergency;

    if (isFallNow) {
      // ── Condition is TRUE ──────────────────────────────────────

      // Reset the "normal since" timer
      _fallCondition.normalSinceTime = null;

      // Increment consecutive readings
      _fallCondition.consecutiveReadings++;

      // Mark when the streak started
      _fallCondition.conditionStartTime ??= DateTime.now();

      final elapsedSeconds =
          DateTime.now().difference(_fallCondition.conditionStartTime!).inSeconds;

      // NORMAL → WARNING: condition has started
      if (_fallCondition.phase == AlertPhase.normal &&
          _fallCondition.consecutiveReadings >= 2) {
        _fallCondition.phase = AlertPhase.warning;
        onAlertPhaseChanged?.call('FALL', AlertPhase.warning);
        debugPrint('⚠️ Fall WARNING — ${_fallCondition.consecutiveReadings} consecutive readings');
      }

      // WARNING → CRITICAL: enough readings AND enough time
      if (_fallCondition.phase == AlertPhase.warning &&
          _fallCondition.consecutiveReadings >= AppConstants.fallConfirmationReadings &&
          elapsedSeconds >= AppConstants.fallConfirmationSeconds) {
        _fallCondition.phase = AlertPhase.critical;

        // Check debounce — don't fire again if we fired recently
        if (_canFireAlert(_fallCondition)) {
          _fallCondition.alertFired = true;
          _fallCondition.lastFiredTime = DateTime.now();
          _fireAlert(
            type: 'fall',
            priority: AlertPriority.high,
            description:
                'Fall detected for ${_elderlyName ?? "elderly user"}. '
                'Confirmed over $elapsedSeconds seconds '
                '(${_fallCondition.consecutiveReadings} readings). '
                'Immediate attention required.',
          );
          onAlertPhaseChanged?.call('FALL', AlertPhase.critical);
        }
      }
    } else {
      // ── Condition returned to NORMAL ──────────────────────────

      if (_fallCondition.phase != AlertPhase.normal) {
        // Start cooldown timer
        _fallCondition.normalSinceTime ??= DateTime.now();

        final normalDuration =
            DateTime.now().difference(_fallCondition.normalSinceTime!).inSeconds;

        // Only resolve after cooldown period
        if (normalDuration >= AppConstants.alertCooldownSeconds) {
          debugPrint('✅ Fall condition resolved after ${normalDuration}s cooldown');
          _fallCondition.reset();
          onAlertPhaseChanged?.call('FALL', AlertPhase.normal);
        }
        // Otherwise: stay in current phase (debounced — don't flicker)
      }

      // Reset consecutive counter regardless
      _fallCondition.consecutiveReadings = 0;
      _fallCondition.conditionStartTime = null;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // INACTIVITY DETECTION — NORMAL → WARNING → CRITICAL
  // ═════════════════════════════════════════════════════════════════

  void _evaluateInactivity() {
    if (_lastMotionTime == null) return;

    final elapsed = DateTime.now().difference(_lastMotionTime!);
    final elapsedMinutes = elapsed.inMinutes;

    if (elapsedMinutes < AppConstants.inactivityWarningMinutes) {
      // ── Motion is recent enough ─────────────────────────────

      if (_inactivityCondition.phase != AlertPhase.normal) {
        // Start cooldown
        _inactivityCondition.normalSinceTime ??= DateTime.now();

        final normalDuration = DateTime.now()
            .difference(_inactivityCondition.normalSinceTime!)
            .inSeconds;

        if (normalDuration >= AppConstants.alertCooldownSeconds) {
          debugPrint('✅ Inactivity resolved after ${normalDuration}s cooldown');
          _inactivityCondition.reset();
          onAlertPhaseChanged?.call('INACTIVITY', AlertPhase.normal);
        }
      }
    } else {
      // ── Inactivity detected ─────────────────────────────────

      _inactivityCondition.normalSinceTime = null;
      _inactivityCondition.conditionStartTime ??= _lastMotionTime;

      // NORMAL → WARNING
      if (elapsedMinutes >= AppConstants.inactivityWarningMinutes &&
          _inactivityCondition.phase == AlertPhase.normal) {
        _inactivityCondition.phase = AlertPhase.warning;
        onAlertPhaseChanged?.call('INACTIVITY', AlertPhase.warning);
        debugPrint('⚠️ Inactivity WARNING — $elapsedMinutes min without movement');
      }

      // WARNING → CRITICAL
      if (elapsedMinutes >= AppConstants.inactivityCriticalMinutes &&
          _inactivityCondition.phase == AlertPhase.warning) {
        _inactivityCondition.phase = AlertPhase.critical;

        if (_canFireAlert(_inactivityCondition)) {
          _inactivityCondition.alertFired = true;
          _inactivityCondition.lastFiredTime = DateTime.now();
          _fireAlert(
            type: 'inactivity',
            priority: AlertPriority.medium,
            description:
                'No activity detected for ${_elderlyName ?? "elderly user"} '
                'in the last $elapsedMinutes minutes.',
          );
          onAlertPhaseChanged?.call('INACTIVITY', AlertPhase.critical);
        }
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // OVERALL STATE — for the Smart Status card
  // ═════════════════════════════════════════════════════════════════

  void _updateOverallState() {
    // Priority: fall > inactivity
    if (_fallCondition.phase == AlertPhase.critical ||
        _inactivityCondition.phase == AlertPhase.critical) {
      _overallPhase = AlertPhase.critical;
    } else if (_fallCondition.phase == AlertPhase.warning ||
        _inactivityCondition.phase == AlertPhase.warning) {
      _overallPhase = AlertPhase.warning;
    } else {
      _overallPhase = AlertPhase.normal;
    }
  }

  void _updateSmartMessage() {
    if (_fallCondition.phase == AlertPhase.critical) {
      _smartMessage = 'Fall detected – immediate attention required';
    } else if (_fallCondition.phase == AlertPhase.warning) {
      _smartMessage = 'Possible fall detected – confirming...';
    } else if (_inactivityCondition.phase == AlertPhase.critical) {
      _smartMessage = 'Unusual inactivity detected – no movement for extended period';
    } else if (_inactivityCondition.phase == AlertPhase.warning) {
      _smartMessage = 'Low activity detected – monitoring closely';
    } else if (!_lastData.presence) {
      _smartMessage = 'Elderly is currently not in sensor range';
    } else if (_lastData.isSleeping) {
      _smartMessage = 'Elderly is sleeping peacefully';
    } else if (!_lastData.motion) {
      _smartMessage = 'Elderly is resting and stable';
    } else {
      _smartMessage = 'Elderly is active and safe';
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════

  /// Check if we're allowed to fire an alert (debounce)
  bool _canFireAlert(_AlertCondition condition) {
    if (condition.alertFired) return false; // already fired this cycle
    if (condition.lastFiredTime == null) return true;

    final sinceLast =
        DateTime.now().difference(condition.lastFiredTime!).inSeconds;
    return sinceLast >= AppConstants.alertDebounceCooldownSeconds;
  }

  /// Fire an alert to Firestore
  Future<void> _fireAlert({
    required String type,
    required AlertPriority priority,
    required String description,
  }) async {
    if (_elderlyUid == null) return;

    try {
      final alert = await FirebaseService.instance.createAlert(
        userId: _elderlyUid!,
        elderlyName: _elderlyName,
        type: type,
        priority: priority,
        description: description,
      );
      GlobalAlertCacheService.instance.addOptimisticAlert(alert);
      debugPrint('🚨 Alert fired: $type - $description');
    } catch (e) {
      debugPrint('Alert creation error: $e');
    }
  }

  /// Manual SOS trigger — bypasses all debouncing (always immediate)
  Future<void> sendSOS({
    required String elderlyUid,
    String? elderlyName,
  }) async {
    final alert = await FirebaseService.instance.createAlert(
      userId: elderlyUid,
      elderlyName: elderlyName,
      type: 'sos',
      priority: AlertPriority.high,
      description:
          'Emergency SOS activated by ${elderlyName ?? "elderly user"}',
    );
    GlobalAlertCacheService.instance.addOptimisticAlert(alert);
  }
}
