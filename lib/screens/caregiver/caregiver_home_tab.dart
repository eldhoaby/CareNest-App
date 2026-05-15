import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/unseen_alert_service.dart';
import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../../core/services/global_alert_cache_service.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import '../../widgets/global_loader.dart';
import '../../models/user_model.dart';

// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
// CAREGIVER HOME TAB â€” Premium Monitoring Dashboard v2
// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 

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
  bool _isLoaded = false;
  StreamSubscription? _profileSub;

  // â”€â”€ Animations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late AnimationController _liveBlinkController;
  late AnimationController _pulseController;
  late AnimationController _cardStaggerController;
  late Animation<double> _blinkAnimation;
  late Animation<double> _pulseAnimation;

  // â”€â”€ Sensor state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  SensorData _sensorData = SensorData.empty;
  bool isConnected = false;
  bool isLoading = true;
  DateTime? lastUpdated;
  StreamSubscription? _sensorSub;

  // â”€â”€ Alerts cache (from cache service) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<AlertModel> _cachedAlerts = [];
  bool _alertsLoaded = false;

  // â”€â”€ Activity tracking â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  DateTime? _sleepStartTime;
  Timer? _tickTimer;

  // â”€â”€ Heart-rate sparkline buffer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              _startSensorStream();
              _startAlertsStream();
              isLoading = true;
            }
          }
          _profileLoaded = true;
          _isLoaded = true;
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
    if (_selectedElderly == null) return;
    
    final currentUid = FirebaseService.instance.currentUid;
    final targetUids = [_selectedElderly!.uid];
    if (currentUid != null) targetUids.add(currentUid);
    
    GlobalAlertCacheService.instance.startListening(targetUids);
    GlobalAlertCacheService.instance.alertsNotifier.addListener(_onAlertsChanged);
    GlobalAlertCacheService.instance.isLoadedNotifier.addListener(_onLoadedChanged);
    _onAlertsChanged(); // Initial sync
    _onLoadedChanged();
  }

  void _onLoadedChanged() {
    if (!mounted) return;
    setState(() {
      _alertsLoaded = GlobalAlertCacheService.instance.isLoadedNotifier.value;
    });
  }

  void _onAlertsChanged() {
    if (!mounted) return;

    final newAlerts = GlobalAlertCacheService.instance.alertsNotifier.value;

    final activeCount = newAlerts.where((a) => a.isActive).length;
    if (widget.activeAlertsCount != null) {
      widget.activeAlertsCount!.value = activeCount;
    }
    
    bool changed = newAlerts.length != _cachedAlerts.length;
    if (!changed) {
      for (int i = 0; i < newAlerts.length; i++) {
        if (newAlerts[i].id != _cachedAlerts[i].id || newAlerts[i].status != _cachedAlerts[i].status) {
          changed = true;
          break;
        }
      }
    }

    if (changed || !_alertsLoaded) {
      setState(() {
        _cachedAlerts = newAlerts;
        _alertsLoaded = GlobalAlertCacheService.instance.isLoadedNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    _liveBlinkController.dispose();
    _pulseController.dispose();
    _cardStaggerController.dispose();
    _profileSub?.cancel();
    _sensorSub?.cancel();
    GlobalAlertCacheService.instance.alertsNotifier.removeListener(_onAlertsChanged);
    GlobalAlertCacheService.instance.isLoadedNotifier.removeListener(_onLoadedChanged);
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
    if (_sleepStartTime == null) return 'â€”';
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
    if (!_isLoaded) {
      return const GlobalLoader(isFullScreen: false);
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 1. GRADIENT HEADER & PROFILE MODAL
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildGradientHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.dashboardGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_greeting, $_caregiverName 👋',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _blinkAnimation,
                          builder: (context, child) => Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? AppColors.success.withValues(alpha: _blinkAnimation.value)
                                  : Colors.orange.withValues(alpha: _blinkAnimation.value),
                              shape: BoxShape.circle,
                              boxShadow: isConnected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.success.withValues(alpha: _blinkAnimation.value * 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _linkedElderlies.length <= 1 
                              ? 'Monitoring ${_selectedElderly?.name ?? '...'}'
                              : 'Monitoring ${_linkedElderlies.length} people',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_linkedElderlies.isNotEmpty) {
                          _showElderlySwitchSheet(context);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedElderly?.name ?? 'Elderly Profile',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (_selectedElderly != null) {
                                _showElderlyProfileModal(context, _selectedElderly!);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _HeaderIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onSwitchTab?.call(1);
                        },
                      ),
                      // Badge: show count of UNSEEN alerts only
                      ValueListenableBuilder<int>(
                        valueListenable: UnseenAlertService.instance.unseenCount,
                        builder: (context, count, _) {
                          if (count <= 0) return const SizedBox.shrink();
                          return Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showElderlySwitchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 24, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Select Patient',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._linkedElderlies.map((elderly) {
                final isSelected = _selectedElderly?.uid == elderly.uid;

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx);
                    if (!isSelected) {
                      setState(() {
                        _selectedElderly = elderly;
                        isLoading = true;
                        
                        _hrHistory.clear();
                        _brHistory.clear();
                        _sleepStartTime = null;
                        
                        _startAlertsStream();
                        _startSensorStream();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.secondarySoft.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                elderly.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                elderly.uid == _selectedElderly?.uid && isConnected
                                    ? 'Online'
                                    : 'Linked Patient',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: elderly.uid == _selectedElderly?.uid && isConnected ? AppColors.success : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showElderlyProfileModal(BuildContext context, UserModel elderly) {
    int age = _calculateAge(elderly.dateOfBirth);
    String ageStr = age > 0 ? '$age yrs' : 'N/A';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySoft.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondarySoft.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    elderly.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Age: $ageStr',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        _modalInfoRow(Icons.phone_rounded, 'Phone', elderly.phone.isNotEmpty ? elderly.phone : 'Not Available'),
                        const SizedBox(height: 12),
                        _modalInfoRow(Icons.email_rounded, 'Email', elderly.email.isNotEmpty ? elderly.email : 'Not Available'),
                        const SizedBox(height: 12),
                        _modalInfoRow(Icons.home_rounded, 'Address', elderly.address ?? 'Not Available'),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: AppColors.border),
                        ),
                        
                        Row(
                          children: [
                            Expanded(child: _modalMiniCard(Icons.bloodtype_rounded, 'Blood Gro...', elderly.bloodGroup ?? 'N/A', AppColors.danger)),
                            const SizedBox(width: 10),
                            Expanded(child: _modalMiniCard(Icons.accessible_rounded, 'Mobility', elderly.mobilityStatus ?? 'N/A', AppColors.info)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _modalMiniCard(Icons.medical_information_rounded, 'Medical Conditions', elderly.medicalConditions ?? 'None reported', AppColors.primary),
                        
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * anim1.value, sigmaY: 8 * anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _modalInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modalMiniCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 2. LIVE STATUS CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildLiveStatusCard() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Live Status', Icons.monitor_heart_outlined),
              const Spacer(),
              AnimatedBuilder(
                animation: _blinkAnimation,
                builder: (context, child) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08 + _blinkAnimation.value * 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: _blinkAnimation.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statusGridItem(
                  icon: Icons.person_rounded,
                  label: 'Presence',
                  value: isConnected ? _sensorData.presenceLabel : '--',
                  color: !isConnected ? AppColors.textMuted : (_sensorData.presence ? AppColors.success : AppColors.warning),
                  description: !isConnected ? 'Sensor is offline. Cannot determine presence.' : (_sensorData.presence ? 'User is currently present in the monitored area.' : 'No user presence detected in the monitored area.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusGridItem(
                  icon: Icons.sensors_rounded,
                  label: 'Sensor',
                  value: isConnected ? 'Online' : 'Offline',
                  color: isConnected ? AppColors.success : AppColors.danger,
                  description: isConnected ? 'Device is online and actively sending real-time data.' : 'Device is offline and disconnected. Please check device power and connectivity.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statusGridItem(
                  icon: Icons.swap_vert_rounded,
                  label: 'Position',
                  value: isConnected ? _sensorData.positionLabel : '--',
                  color: !isConnected ? AppColors.textMuted : AppColors.success,
                  description: !isConnected ? 'Sensor is offline. Cannot track position.' : 'User is currently ${_sensorData.positionLabel.toLowerCase()}.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusGridItem(
                  icon: Icons.air_rounded,
                  label: 'Respiration',
                  value: isConnected ? _sensorData.breathingLabel : '--',
                  color: !isConnected ? AppColors.textMuted : (_sensorData.abnormalBreathing ? AppColors.danger : AppColors.success),
                  description: !isConnected ? 'Sensor is offline. Cannot track respiration.' : (_sensorData.abnormalBreathing ? 'Breathing rate is abnormal. Please monitor the user.' : 'Breathing rate is within normal range.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusGridItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String description,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          _showStatusDialog(
            context,
            title: label,
            value: value,
            icon: icon,
            color: color,
            description: description,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, {required String title, required String value, required IconData icon, required Color color, required String description}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 20)),
                const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(top: -50, right: -50, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.07)))),
                  Positioned(bottom: -30, left: -40, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.05)))),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8)),
                              BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: -2, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Container(margin: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 36)),
                        ),
                        const SizedBox(height: 24),
                        Text('$title Status', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.25), width: 1)),
                          child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 20),
                        Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary.withValues(alpha: 0.9), height: 1.5, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); },
                            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: const Text('Got it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(top: 12, right: 12, child: IconButton(onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); }, icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22))),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return BackdropFilter(filter: ImageFilter.blur(sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value), child: FadeTransition(opacity: anim1, child: ScaleTransition(scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic), child: child)));
      },
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 3. VITAL SIGNS CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildVitalSignsCard() {
    final hrValue = isConnected ? _sensorData.heartRate : 0;
    final brValue = isConnected ? _sensorData.breathingRate : 0.0;
    final hrNormal = hrValue >= 50 && hrValue <= 100;
    final brNormal = brValue >= 10 && brValue <= 24;
    final hrColor = !isConnected ? AppColors.textMuted : (hrNormal ? AppColors.success : AppColors.danger);
    final brColor = !isConnected ? AppColors.textMuted : (_sensorData.abnormalBreathing ? AppColors.danger : (brNormal ? AppColors.success : AppColors.warning));

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Vital Signs', Icons.favorite_rounded),
              const Spacer(),
              if (_sensorData.abnormalBreathing && isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.danger, size: 14),
                      const SizedBox(width: 4),
                      Text(_sensorData.abnormalReason.isNotEmpty ? _sensorData.abnormalReason : 'Abnormal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _vitalBlock(icon: Icons.favorite_rounded, label: 'Heart Rate', value: isConnected ? '$hrValue' : '--', unit: 'BPM', color: hrColor, sparkline: _hrHistory)),
              Container(width: 1, height: 80, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(child: _vitalBlock(icon: Icons.air_rounded, label: 'Respiration', value: isConnected ? brValue.toStringAsFixed(0) : '--', unit: '/min', color: brColor, sparkline: _brHistory)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalBlock({required IconData icon, required String label, required String value, required String unit, required Color color, List<double>? sparkline}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: double.tryParse(value) ?? 0.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, animVal, _) => Text(
                animVal.toStringAsFixed(0),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color, height: 1.0),
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
          ],
        ),
        if (sparkline != null && sparkline.length > 3) ...[
          const SizedBox(height: 10),
          SizedBox(height: 28, child: CustomPaint(size: const Size(double.infinity, 28), painter: _SparklinePainter(sparkline, color))),
        ],
      ],
    );
  }
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 4. SMART STATUS CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSmartStatusCard() {
    String phaseLabel;
    String message;
    Color bgColor;
    Color accentColor;
    IconData icon;

    if (!isConnected) {
      phaseLabel = 'Offline';
      message = 'Sensor disconnected. Waiting for connection...';
      bgColor = const Color(0xFFF3F4F6);
      accentColor = AppColors.textMuted;
      icon = Icons.wifi_off_rounded;
    } else if (_sensorData.isEmergency) {
      phaseLabel = 'Critical';
      message = 'Emergency detected \u2014 immediate attention required!';
      bgColor = const Color(0xFFFEE2E2);
      accentColor = AppColors.danger;
      icon = Icons.warning_rounded;
    } else if (_sensorData.abnormalBreathing) {
      phaseLabel = 'Warning';
      message = 'Abnormal breathing detected. Please monitor the user.';
      bgColor = const Color(0xFFFEF3C7);
      accentColor = AppColors.warning;
      icon = Icons.info_rounded;
    } else if (_sensorData.heartRate > 0 && (_sensorData.heartRate < 50 || _sensorData.heartRate > 100)) {
      phaseLabel = 'Warning';
      message = 'Elevated heart rate detected.';
      bgColor = const Color(0xFFFEF3C7);
      accentColor = AppColors.warning;
      icon = Icons.favorite_rounded;
    } else if (!_sensorData.motion && _sensorData.presence && !_sensorData.isSleeping) {
      phaseLabel = 'Warning';
      message = 'Low activity detected recently.';
      bgColor = const Color(0xFFFEF3C7);
      accentColor = AppColors.warning;
      icon = Icons.directions_run_rounded;
    } else {
      phaseLabel = 'Normal';
      message = 'All vitals are within normal range.';
      bgColor = AppColors.primarySoft.withValues(alpha: 0.1);
      accentColor = AppColors.primarySoft;
      icon = Icons.psychology_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Smart Insight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor.withValues(alpha: 0.7), letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(phaseLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(message, key: ValueKey(message), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accentColor, height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 5. ALERTS PREVIEW
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildAlertsPreview() {
    if (_selectedElderly == null || _selectedElderly!.uid.isEmpty) return const SizedBox.shrink();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Alerts', Icons.notifications_active_outlined)),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () { HapticFeedback.lightImpact(); widget.onSwitchTab?.call(1); },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !_alertsLoaded
                ? const SizedBox(height: 60)
                : _cachedAlerts.isEmpty
                    ? Container(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                            SizedBox(width: 10),
                            Text('No alerts â€” all clear!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ],
                        ),
                      )
                    : Column(
                        key: ValueKey('alerts_${_cachedAlerts.length}_${_cachedAlerts.first.id}'),
                        children: _cachedAlerts.take(2).map((alert) => _alertPreviewRow(alert)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _alertPreviewRow(AlertModel alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: alert.isActive ? alert.priorityColor.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () { HapticFeedback.lightImpact(); widget.onSwitchTab?.call(1); },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: alert.priorityColor, width: 3))),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: alert.priorityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(alert.typeIcon, color: alert.priorityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.typeLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(alert.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(alert.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    if (alert.isActive) Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 6. ACTIVITY SUMMARY
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildActivitySummary() {
    final today = DateTime.now();
    final alertsTodayCount = _cachedAlerts.where((a) => a.timestamp != null && a.timestamp!.year == today.year && a.timestamp!.month == today.month && a.timestamp!.day == today.day).length;

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Activity', Icons.directions_run_rounded)),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () { HapticFeedback.lightImpact(); widget.onSwitchTab?.call(2); },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(icon: Icons.directions_run_rounded, label: 'Active Time', value: '1h 30m', valueColor: AppColors.success),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _infoRow(icon: Icons.directions_walk_rounded, label: 'Movement Time', value: '45 min', valueColor: AppColors.primary),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _infoRow(icon: Icons.warning_rounded, label: 'Total Alerts Today', value: alertsTodayCount.toString(), valueColor: alertsTodayCount > 0 ? AppColors.danger : AppColors.textSecondary),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 7. SLEEP STATUS CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSleepCard() {
    final isSleeping = _sensorData.isSleeping;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSleeping ? AppColors.primarySoft.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSleeping ? AppColors.primarySoft.withValues(alpha: 0.2) : AppColors.border, width: 1),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(isSleeping ? Icons.bedtime_rounded : Icons.wb_sunny_rounded, color: AppColors.primarySoft, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sleep Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(isSleeping ? 'Sleeping' : 'Awake', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isSleeping ? AppColors.primarySoft : AppColors.textPrimary)),
              ],
            ),
          ),
          if (isSleeping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(_sleepDuration, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primarySoft)),
            ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // HELPER METHDOS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value, required Color valueColor}) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: valueColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: valueColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return const GlobalLoader(isFullScreen: false);
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// REUSABLE PRIVATE WIDGETS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.2),
        onTap: onTap,
        child: Container(width: 48, height: 48, alignment: Alignment.center, child: Icon(icon, color: Colors.white, size: 24)),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: const EdgeInsets.all(24), borderRadius: 24, child: child);
  }
}



class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final step = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y); fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height); fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.data.length != data.length || (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
