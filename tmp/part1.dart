import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/alert_service.dart';
import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../../widgets/premium/glass_card.dart';
import '../../models/user_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CAREGIVER HOME TAB — Premium Monitoring Dashboard v2
// ═══════════════════════════════════════════════════════════════════════════

class CaregiverHomeTab extends StatefulWidget {
  final Function(int)? onSwitchTab;
  final ValueNotifier<int>? activeAlertsCount;

  const CaregiverHomeTab({
    super.key,
    this.onSwitchTab,
    this.activeAlertsCount,
  });

  @override
  State<CaregiverHomeTab> createState() => _CaregiverHomeTabState();
}

class _CaregiverHomeTabState extends State<CaregiverHomeTab>
    with TickerProviderStateMixin {
  String _caregiverName = 'Caregiver';
  List<UserModel> _linkedElderlies = [];
  UserModel? _selectedElderly;
  bool _profileLoaded = false;
  StreamSubscription? _profileSub;

  // ── Animations ──────────────────────────────────────────────────
  late AnimationController _liveBlinkController;
  late AnimationController _pulseController;
  late AnimationController _cardStaggerController;
  late Animation<double> _blinkAnimation;
  late Animation<double> _pulseAnimation;

  // ── Sensor state ────────────────────────────────────────────────
  SensorData _sensorData = SensorData.empty;
  bool isConnected = false;
  bool isLoading = true;
  DateTime? lastUpdated;
  StreamSubscription? _sensorSub;

  // ── Alerts cache (prevents StreamBuilder flickering) ────────────
  List<AlertModel> _cachedAlerts = [];
  bool _alertsLoaded = false;
  StreamSubscription? _alertsSub;

  // ── Activity tracking ──────────────────────────────────────────
  DateTime? _sleepStartTime;
  Timer? _tickTimer;

  // ── Heart-rate sparkline buffer ────────────────────────────────
  final List<double> _hrHistory = [];
  final List<double> _brHistory = [];
  static const int _maxHrSamples = 20;

  @override
  void initState() {
    super.initState();

    // Blinking live-dot animation
    _liveBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _liveBlinkController, curve: Curves.easeInOut),
    );

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Card entrance stagger
    _cardStaggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _startProfileStream();

    // Tick every second for relative timestamps & inactivity timer
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startProfileStream() {
    _profileSub = FirebaseService.instance.userProfileStream().listen((snapshot) async {
      if (!mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      List<String> linkedUids = [];
      if (data['linkedElderlyUids'] is List) {
        linkedUids = List<String>.from(data['linkedElderlyUids']);
      } else if (data['linkedElderlyUid'] != null) {
        linkedUids = [data['linkedElderlyUid']];
      }
      
      List<UserModel> elderlies = [];
      for (String uid in linkedUids) {
        final user = await FirebaseService.instance.getLinkedElderly(uid);
        if (user != null) {
          elderlies.add(user);
        }
      }

      if (mounted) {
        setState(() {
          _caregiverName = data['name'] ?? 'Caregiver';
          _linkedElderlies = elderlies;
          if (_selectedElderly == null || !elderlies.any((e) => e.uid == _selectedElderly!.uid)) {
            _selectedElderly = elderlies.isNotEmpty ? elderlies.first : null;
            if (_selectedElderly != null) {
              _startAlertsStream();
              _startSensorStream();
              isLoading = true;
            }
          }
          _profileLoaded = true;
        });
      }
    });
  }

  void _startSensorStream() {
    _sensorSub?.cancel();
    _sensorSub = FirebaseService.instance.sensorStream().listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          if (mounted) {
            setState(() {
              isConnected = false;
              isLoading = false;
            });
          }
          return;
        }

        final map = Map<String, dynamic>.from(data as Map);
        final sensorData = SensorData.fromMap(map);

        if (mounted) {
          setState(() {
            _sensorData = sensorData;
            isConnected = true;
            isLoading = false;
            lastUpdated = DateTime.now();

            if (sensorData.isSleeping && _sleepStartTime == null) {
              _sleepStartTime = DateTime.now();
            } else if (!sensorData.isSleeping) {
              _sleepStartTime = null;
            }

            if (sensorData.heartRate > 0) {
              _hrHistory.add(sensorData.heartRate.toDouble());
              if (_hrHistory.length > _maxHrSamples) {
                _hrHistory.removeAt(0);
              }
            }
            if (sensorData.breathingRate > 0) {
              _brHistory.add(sensorData.breathingRate);
              if (_brHistory.length > _maxHrSamples) {
                _brHistory.removeAt(0);
              }
            }
          });
        }
      },
      onError: (error) {
        debugPrint('Sensor error: $error');
        if (mounted) {
          setState(() {
            isConnected = false;
            isLoading = false;
          });
        }
      },
    );
  }

  void _startAlertsStream() {
    _alertsSub?.cancel();
    if (_selectedElderly == null) return;

    _alertsSub = FirebaseService.instance
        .alertsStream(_selectedElderly!.uid)
        .listen((snapshot) {
      if (!mounted) return;

      final newAlerts = snapshot.docs
          .map((d) => AlertModel.fromDoc(d))
          .toList();

      newAlerts.sort((a, b) => (b.timestamp ?? DateTime.now())
          .compareTo(a.timestamp ?? DateTime.now()));

      final activeCount = newAlerts.where((a) => a.isActive).length;
      if (widget.activeAlertsCount != null) {
        widget.activeAlertsCount!.value = activeCount;
      }
      
      final changed = newAlerts.length != _cachedAlerts.length ||
          (newAlerts.isNotEmpty &&
              _cachedAlerts.isNotEmpty &&
              newAlerts.first.id != _cachedAlerts.first.id);

      if (changed || !_alertsLoaded) {
        setState(() {
          _cachedAlerts = newAlerts;
          _alertsLoaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _liveBlinkController.dispose();
    _pulseController.dispose();
    _cardStaggerController.dispose();
    _profileSub?.cancel();
    _sensorSub?.cancel();
    _alertsSub?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _sleepDuration {
    if (_sleepStartTime == null) return '—';
    final diff = DateTime.now().difference(_sleepStartTime!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  int _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return 0;
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0; // Return 0 if format is unrecognized
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded || (isLoading && _selectedElderly != null)) {
      return _buildLoadingSkeleton();
    }
    if (_selectedElderly == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_off_rounded, size: 60, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text('No Elderly Linked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text('Link an elderly account to view their dashboard.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildGradientHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isConnected) ...[
                  _buildOfflineBanner(),
                  const SizedBox(height: 16),
                ],
                _staggeredCard(0, _buildLiveStatusCard()),
                const SizedBox(height: 16),
                _staggeredCard(1, _buildVitalSignsCard()),
                const SizedBox(height: 16),
                _staggeredCard(2, _buildSmartStatusCard()),
                const SizedBox(height: 16),
                _staggeredCard(3, _buildAlertsPreview()),
                const SizedBox(height: 16),
                _staggeredCard(4, _buildActivitySummary()),
                const SizedBox(height: 16),
                _staggeredCard(5, _buildSleepCard()),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensor Offline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Displaying last known values. Reconnecting...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staggeredCard(int index, Widget child) {
    final begin = (index * 0.1).clamp(0.0, 0.6);
    final end = (begin + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _cardStaggerController,
      builder: (context, _) {
        final value = Curves.easeOutCubic.transform(
          (((_cardStaggerController.value - begin) / (end - begin))
              .clamp(0.0, 1.0)),
        );
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
    );
  }

