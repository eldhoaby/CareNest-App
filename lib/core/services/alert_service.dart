import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../constants/app_constants.dart';
import 'firebase_service.dart';

/// Smart activity detection engine
/// Monitors sensor data and generates alerts for falls and inactivity
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  StreamSubscription<DatabaseEvent>? _sensorSub;
  Timer? _inactivityTimer;

  DateTime? _lastMotionTime;
  bool _fallAlertSent = false;
  bool _inactivityAlertSent = false;

  String? _elderlyUid;
  String? _elderlyName;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  SensorData _lastData = SensorData.empty;
  SensorData get lastData => _lastData;

  /// Callbacks for UI updates
  void Function(SensorData data)? onSensorUpdate;
  void Function(String alertType)? onAlertFired;

  /// Start monitoring sensor data for an elderly user
  void startMonitoring({
    required String elderlyUid,
    required String elderlyName,
  }) {
    if (_isMonitoring) stopMonitoring();

    _elderlyUid = elderlyUid;
    _elderlyName = elderlyName;
    _isMonitoring = true;
    _fallAlertSent = false;
    _inactivityAlertSent = false;
    _lastMotionTime = DateTime.now();

    // Listen to sensor stream
    _sensorSub = FirebaseService.instance.sensorStream().listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) return;

        final map = Map<String, dynamic>.from(data as Map);
        final sensorData = SensorData.fromMap(map);

        _lastData = sensorData;
        onSensorUpdate?.call(sensorData);

        _processSensorData(sensorData);
      },
      onError: (error) {
        debugPrint('AlertService sensor error: $error');
      },
    );

    // Start inactivity timer
    _startInactivityCheck();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _sensorSub?.cancel();
    _sensorSub = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _isMonitoring = false;
    _elderlyUid = null;
    _elderlyName = null;
  }

  /// Process incoming sensor data
  void _processSensorData(SensorData data) {
    // Motion detected → update timestamp, reset inactivity
    if (data.motion || data.presence) {
      _lastMotionTime = DateTime.now();
      _inactivityAlertSent = false;
    }

    // Fall detection
    if (data.isEmergency && !_fallAlertSent) {
      _fallAlertSent = true;
      _fireAlert(
        type: AlertType.fall,
        priority: AlertPriority.high,
        description:
            'Fall detected for ${_elderlyName ?? "elderly user"}. Immediate attention required.',
      );
      onAlertFired?.call('FALL');
    }

    // Reset fall flag when recovered
    if (!data.isEmergency) {
      _fallAlertSent = false;
    }
  }

  /// Periodic inactivity check
  void _startInactivityCheck() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkInactivity(),
    );
  }

  void _checkInactivity() {
    if (_lastMotionTime == null || _inactivityAlertSent) return;

    final elapsed = DateTime.now().difference(_lastMotionTime!);

    if (elapsed.inMinutes >= AppConstants.inactivityTimeoutMinutes) {
      _inactivityAlertSent = true;
      _fireAlert(
        type: AlertType.inactivity,
        priority: AlertPriority.medium,
        description:
            'No activity detected for ${_elderlyName ?? "elderly user"} '
            'in the last ${AppConstants.inactivityTimeoutMinutes} minutes.',
      );
      onAlertFired?.call('INACTIVITY');
    }
  }

  /// Fire an alert to Firestore
  Future<void> _fireAlert({
    required AlertType type,
    required AlertPriority priority,
    required String description,
  }) async {
    if (_elderlyUid == null) return;

    try {
      await FirebaseService.instance.createAlert(
        userId: _elderlyUid!,
        elderlyName: _elderlyName,
        type: type,
        priority: priority,
        description: description,
      );
      debugPrint('🚨 Alert fired: ${type.name} - $description');
    } catch (e) {
      debugPrint('Alert creation error: $e');
    }
  }

  /// Manual SOS trigger
  Future<void> sendSOS({
    required String elderlyUid,
    String? elderlyName,
  }) async {
    await FirebaseService.instance.createAlert(
      userId: elderlyUid,
      elderlyName: elderlyName,
      type: AlertType.sos,
      priority: AlertPriority.high,
      description:
          'Emergency SOS activated by ${elderlyName ?? "elderly user"}',
    );
  }
}
