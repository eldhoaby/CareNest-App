import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/unseen_alert_service.dart';
import '../../core/services/global_alert_cache_service.dart';
import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import '../../widgets/global_loader.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ELDERLY HOME TAB — Premium Monitoring Dashboard v2
// ═══════════════════════════════════════════════════════════════════════════

class ElderlyHomeTab extends StatefulWidget {
  final String userName;
  final String userId;
  final VoidCallback? onNavigateToAlerts;
  final VoidCallback? onNavigateToActivity;

  const ElderlyHomeTab({
    super.key,
    required this.userName,
    required this.userId,
    this.onNavigateToAlerts,
    this.onNavigateToActivity,
  });

  @override
  State<ElderlyHomeTab> createState() => _ElderlyHomeTabState();
}

class _ElderlyHomeTabState extends State<ElderlyHomeTab>
    with TickerProviderStateMixin {
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

  // ── Alerts cache (from Global Cache) ────────────
  List<AlertModel> _cachedAlerts = [];
  bool _alertsLoaded = false;

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

    // Pulse animation for SOS glow
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

    _startSensorStream();
    
    // Initialize alerts from global cache
    GlobalAlertCacheService.instance.startListening([widget.userId]);
    GlobalAlertCacheService.instance.alertsNotifier.addListener(_onAlertsChanged);
    GlobalAlertCacheService.instance.isLoadedNotifier.addListener(_onLoadedChanged);
    _onAlertsChanged(); // Initial sync
    _onLoadedChanged();

    // Tick every second for relative timestamps & inactivity timer
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startSensorStream() {
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

            // Track motion times
            // (Removed _lastMotionTime as Activity Summary is static)

            // Track sleep start
            if (sensorData.isSleeping && _sleepStartTime == null) {
              _sleepStartTime = DateTime.now();
            } else if (!sensorData.isSleeping) {
              _sleepStartTime = null;
            }

            // Sparkline buffer
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

  Future<void> _sendSOS() async {
    HapticFeedback.heavyImpact();
    try {
      await AlertService.instance.sendSOS(
        elderlyUid: widget.userId,
        elderlyName: widget.userName,
      );
      // Feature #8: Play SOS sent sound
      SoundService.instance.playSosSent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.sos_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text('Emergency SOS dispatched!',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    } catch (e) {
      debugPrint('SOS error: $e');
    }
  }

  void _onLoadedChanged() {
    if (!mounted) return;
    setState(() {
      _alertsLoaded = GlobalAlertCacheService.instance.isLoadedNotifier.value;
    });
  }

  /// Read from GlobalAlertCacheService
  void _onAlertsChanged() {
    if (!mounted) return;
    
    final newAlerts = GlobalAlertCacheService.instance.alertsNotifier.value;
    
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
    if (_sleepStartTime == null) return '—';
    final diff = DateTime.now().difference(_sleepStartTime!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingSkeleton();
    }

    return Column(
      children: [
        // 1. Gradient Header (not scrollable)
        _buildGradientHeader(),

        // 2–8. Scrollable content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sensor offline banner
                if (!isConnected) ...[
                  _buildOfflineBanner(),
                  const SizedBox(height: 16),
                ],

                // 2. Live Status Card
                _staggeredCard(0, _buildLiveStatusCard()),
                const SizedBox(height: 16),

                // 3. Vital Signs Card
                _staggeredCard(1, _buildVitalSignsCard()),
                const SizedBox(height: 16),

                // 4. Smart Status Card
                _staggeredCard(2, _buildSmartStatusCard()),
                const SizedBox(height: 16),

                // 5. Alerts Preview Card
                _staggeredCard(3, _buildAlertsPreview()),
                const SizedBox(height: 16),

                // 6. Activity Summary Card
                _staggeredCard(4, _buildActivitySummary()),
                const SizedBox(height: 16),

                // 7. Sleep Status Card
                _staggeredCard(5, _buildSleepCard()),
                const SizedBox(height: 24),

                // 8. Emergency SOS
                _staggeredCard(6, _buildSOSButton()),

                const SizedBox(height: 100), // bottom nav clearance
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Offline banner when sensor is disconnected
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
            child: const Icon(Icons.wifi_off_rounded,
                color: AppColors.warning, size: 20),
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

  /// Animated card entrance with stagger effect
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

  // ════════════════════════════════════════════════════════════════
  // 1. GRADIENT HEADER
  // ════════════════════════════════════════════════════════════════

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
          padding: const EdgeInsets.fromLTRB(24, 16, 20, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting & name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_greeting 👋',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userName.isEmpty ? 'User' : widget.userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Live indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _blinkAnimation,
                            builder: (context, child) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppColors.success
                                        .withValues(
                                            alpha: _blinkAnimation.value)
                                    : Colors.orange.withValues(
                                        alpha: _blinkAnimation.value),
                                shape: BoxShape.circle,
                                boxShadow: isConnected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.success
                                              .withValues(
                                                  alpha:
                                                      _blinkAnimation.value *
                                                          0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'Monitoring Active' : 'Connecting...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bell icon with unseen alerts badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _HeaderIconButton(
                    icon: Icons.notifications_outlined,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onNavigateToAlerts?.call();
                    },
                  ),
                  // Badge: show count of UNSEEN alerts only
                  ValueListenableBuilder<int>(
                    valueListenable: UnseenAlertService.instance.unseenCount,
                    builder: (context, count, _) {
                      if (count <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 10,
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
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 2. LIVE STATUS CARD (2×2 Grid)
  // ════════════════════════════════════════════════════════════════

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success
                        .withValues(alpha: 0.08 + _blinkAnimation.value * 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.success
                              .withValues(alpha: _blinkAnimation.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2×2 Grid
          Row(
            children: [
              Expanded(
                child: _statusGridItem(
                  icon: Icons.person_rounded,
                  label: 'Presence',
                  value: isConnected ? _sensorData.presenceLabel : '--',
                  color: !isConnected
                      ? AppColors.textMuted
                      : (_sensorData.presence
                          ? AppColors.success
                          : AppColors.warning),
                  description: !isConnected 
                      ? 'Sensor is offline. Cannot determine presence.'
                      : (_sensorData.presence 
                          ? 'User is currently present in the monitored area.'
                          : 'No user presence detected in the monitored area.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusGridItem(
                  icon: Icons.sensors_rounded,
                  label: 'Sensor',
                  value: isConnected ? 'Online' : 'Offline',
                  color: isConnected ? AppColors.success : AppColors.danger,
                  description: isConnected
                      ? 'Device is online and actively sending real-time data.'
                      : 'Device is offline and disconnected. Please check device power and connectivity.',
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
                  value: isConnected ? 'Standing' : '--',
                  color: !isConnected 
                      ? AppColors.textMuted
                      : AppColors.success,
                  description: !isConnected
                      ? 'Sensor is offline. Cannot track position.'
                      : 'User is currently standing.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusGridItem(
                  icon: Icons.air_rounded,
                  label: 'Respiration',
                  value: isConnected ? _sensorData.breathingLabel : '--',
                  color: !isConnected
                      ? AppColors.textMuted
                      : (_sensorData.abnormalBreathing
                          ? AppColors.danger
                          : AppColors.success),
                  description: !isConnected
                      ? 'Sensor is offline. Cannot track respiration.'
                      : (_sensorData.abnormalBreathing
                          ? 'Breathing rate is abnormal. Please monitor the user.'
                          : 'Breathing rate is within normal range.'),
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
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

  void _showStatusDialog(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String description,
  }) {
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
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                const BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Subtle contextual background blobs
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.07),
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
                        color: color.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with rich glow
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: color.withValues(alpha: 0.1),
                                blurRadius: 8,
                                spreadRadius: -2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 36),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          '$title Status',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Description
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Primary Action Button
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Got it',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.hardEdge,
                      child: IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                      ),
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
          filter: ImageFilter.blur(
            sigmaX: 12 * anim1.value,
            sigmaY: 12 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: anim1,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 3. VITAL SIGNS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildVitalSignsCard() {
    final hrValue = isConnected ? _sensorData.heartRate : 0;
    final brValue = isConnected ? _sensorData.breathingRate : 0.0;
    final hrNormal = hrValue >= 50 && hrValue <= 100;
    final brNormal = brValue >= 10 && brValue <= 24;
    final hrColor = !isConnected
        ? AppColors.textMuted
        : (hrNormal ? AppColors.success : AppColors.danger);
    final brColor = !isConnected
        ? AppColors.textMuted
        : (_sensorData.abnormalBreathing
            ? AppColors.danger
            : (brNormal ? AppColors.success : AppColors.warning));

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: AppColors.danger, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _sensorData.abnormalReason.isNotEmpty
                            ? _sensorData.abnormalReason
                            : 'Abnormal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Heart Rate
              Expanded(
                child: _vitalBlock(
                  icon: Icons.favorite_rounded,
                  label: 'Heart Rate',
                  value: isConnected ? '$hrValue' : '--',
                  unit: 'BPM',
                  color: hrColor,
                  sparkline: _hrHistory,
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 80,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Breathing Rate
              Expanded(
                child: _vitalBlock(
                  icon: Icons.air_rounded,
                  label: 'Respiration',
                  value: isConnected
                      ? brValue.toStringAsFixed(0)
                      : '--',
                  unit: '/min',
                  color: brColor,
                  sparkline: _brHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalBlock({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    List<double>? sparkline,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: double.parse(value)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, animVal, _) => Text(
                animVal.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (sparkline != null && sparkline.length > 3) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: CustomPaint(
              size: const Size(double.infinity, 28),
              painter: _SparklinePainter(sparkline, color),
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 4. SMART STATUS CARD — uses stabilized AlertService state
  // ════════════════════════════════════════════════════════════════

  Widget _buildSmartStatusCard() {
    // Use the stabilized message from AlertService (debounced, state-machine-based)
    final alertPhase = AlertService.instance.overallPhase;
    final message = AlertService.instance.smartMessage;

    Color bgColor;
    Color accentColor;
    IconData icon;
    String phaseLabel;

    switch (alertPhase) {
      case AlertPhase.critical:
        bgColor = const Color(0xFFFEE2E2);
        accentColor = AppColors.danger;
        icon = Icons.warning_rounded;
        phaseLabel = '🔴 Critical';
        break;
      case AlertPhase.warning:
        bgColor = const Color(0xFFFEF3C7);
        accentColor = AppColors.warning;
        icon = Icons.info_rounded;
        phaseLabel = '🟡 Warning';
        break;
      case AlertPhase.normal:
        bgColor = AppColors.primarySoft.withValues(alpha: 0.1);
        accentColor = AppColors.primarySoft;
        icon = Icons.psychology_rounded;
        phaseLabel = '🟢 Normal';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Smart Insight',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        phaseLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 5. ALERTS PREVIEW (with "View All" → Alerts Tab)
  // ════════════════════════════════════════════════════════════════

  Widget _buildAlertsPreview() {
    if (widget.userId.isEmpty) return const SizedBox.shrink();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Bug #4 fix: Flexible prevents overflow when title + button exceed width
              Expanded(
                child: _sectionTitle(
                    'Alerts', Icons.notifications_active_outlined),
              ),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNavigateToAlerts?.call();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Cached alerts — no StreamBuilder, no flickering
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
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'No alerts — all clear!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        key: ValueKey('alerts_${_cachedAlerts.length}_${_cachedAlerts.first.id}'),
                        children: _cachedAlerts
                            .take(2)
                            .map((alert) => _alertPreviewRow(alert))
                            .toList(),
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
        color: alert.isActive
            ? alert.priorityColor.withValues(alpha: 0.05)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onNavigateToAlerts?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(
                  color: alert.priorityColor,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: alert.priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(alert.typeIcon,
                      color: alert.priorityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.typeLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      alert.timeAgo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (alert.isActive)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 6. ACTIVITY SUMMARY (with "View Details" → Activity Tab)
  // ════════════════════════════════════════════════════════════════

  Widget _buildActivitySummary() {
    // Count alerts today dynamically
    final today = DateTime.now();
    final alertsTodayCount = _cachedAlerts.where((a) =>
        a.timestamp != null &&
        a.timestamp!.year == today.year &&
        a.timestamp!.month == today.month &&
        a.timestamp!.day == today.day).length;

    // Static preferred values for activity metrics
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Bug #4 fix: Flexible prevents row overflow on narrow screens
              Expanded(
                child: _sectionTitle(
                    'Activity', Icons.directions_run_rounded),
              ),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNavigateToActivity?.call();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(
            icon: Icons.directions_run_rounded,
            label: 'Active Time',
            value: '1h 30m',
            valueColor: AppColors.success,
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _infoRow(
            icon: Icons.directions_walk_rounded,
            label: 'Movement Time',
            value: '45 min',
            valueColor: AppColors.primary,
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _infoRow(
            icon: Icons.warning_rounded,
            label: 'Alerts Today',
            value: alertsTodayCount.toString(),
            valueColor: alertsTodayCount > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 7. SLEEP STATUS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildSleepCard() {
    final isSleeping = _sensorData.isSleeping;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSleeping ? AppColors.primarySoft.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSleeping
              ? AppColors.primarySoft.withValues(alpha: 0.2)
              : AppColors.border,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSleeping ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
              color: AppColors.primarySoft,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sleep Status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSleeping ? 'Sleeping' : 'Awake',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isSleeping
                        ? AppColors.primarySoft
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (isSleeping)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _sleepDuration,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primarySoft,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 8. EMERGENCY SOS BUTTON
  // ════════════════════════════════════════════════════════════════

  Widget _buildSOSButton() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: PremiumAnimatedButton(
            height: 64,
            gradient: AppColors.emergencyGradient,
            showGlow: true,
            onPressed: _showSOSConfirmation,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sos_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Call Help 🚨',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Press if you need immediate help',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Feature #6: Cancelable SOS with 5-second countdown
  void _showSOSConfirmation() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SOSCountdownDialog(
        onConfirmed: () {
          Navigator.pop(ctx);
          _sendSOS();
        },
        onCancelled: () {
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: valueColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return const GlobalLoader(isFullScreen: false);
  }


}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE PRIVATE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Glassmorphic header icon button
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
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Standard dashboard card with white background & soft shadow
class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: child,
    );
  }
}

/// Skeleton loading block


/// Mini sparkline painter for heart rate history
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
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final step = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data.length != data.length ||
      (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}

// ══════════════════════════════════════════════════════════════════════════════
// SOS COUNTDOWN DIALOG — Feature #6: Cancelable SOS with 5-second countdown
// ══════════════════════════════════════════════════════════════════════════════

class _SOSCountdownDialog extends StatefulWidget {
  final VoidCallback onConfirmed;
  final VoidCallback onCancelled;

  const _SOSCountdownDialog({
    required this.onConfirmed,
    required this.onCancelled,
  });

  @override
  State<_SOSCountdownDialog> createState() => _SOSCountdownDialogState();
}

class _SOSCountdownDialogState extends State<_SOSCountdownDialog>
    with SingleTickerProviderStateMixin {
  static const int _countdownSeconds = 5;
  late AnimationController _animController;
  int _secondsRemaining = _countdownSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    )..forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      HapticFeedback.mediumImpact();

      if (_secondsRemaining <= 0) {
        timer.cancel();
        widget.onConfirmed();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated countdown circle
            SizedBox(
              width: 100,
              height: 100,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: 1.0 - _animController.value,
                          strokeWidth: 6,
                          backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.danger),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Sending SOS...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            const Text(
              'Emergency alert will be sent to your\ncaregivers and emergency contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Buttons: Cancel + Send Now (Bug #3 fix: responsive layout)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancelled,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: AppColors.textMuted.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      _countdownTimer?.cancel();
                      widget.onConfirmed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'SEND NOW',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}