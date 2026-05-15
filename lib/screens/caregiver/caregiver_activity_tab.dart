import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../../widgets/premium/glass_card.dart';
import '../../models/user_model.dart';
import '../../core/services/global_alert_cache_service.dart';
import '../../widgets/global_loader.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CAREGIVER ACTIVITY TAB — Premium Health Analytics Dashboard
// ═══════════════════════════════════════════════════════════════════════════

class CaregiverActivityTab extends StatefulWidget {
  const CaregiverActivityTab({super.key});

  @override
  State<CaregiverActivityTab> createState() => _CaregiverActivityTabState();
}

class _CaregiverActivityTabState extends State<CaregiverActivityTab>
    with SingleTickerProviderStateMixin {
  List<UserModel> _linkedElderlies = [];
  UserModel? _selectedElderly;
  bool _profileLoaded = false;
  StreamSubscription? _profileSub;

  // ── Sensor state ────────────────────────────────────────────────
  SensorData _sensorData = SensorData.empty;
  bool isConnected = false;
  StreamSubscription? _sensorSub;
  Timer? _tickTimer;

  DateTime? _lastMotionTime;

  // ── Time filter ─────────────────────────────────────────────────
  bool _isDayView = true; // true = Day, false = Week

  // ── Chart data buffers (collected from sensor stream) ───────────
  final List<double> _hrHistory = [];
  final List<double> _brHistory = [];
  static const int _maxSamples = 20;

  // ── Activity log ────────────────────────────────────────────────
  int _alertCount = 0;
  Duration _movementDuration = Duration.zero;
  Duration _inactivityTotal = Duration.zero;
  Duration _sleepDuration = Duration.zero;
  DateTime? _sleepStart;

  // ── Animation ───────────────────────────────────────────────────
  late AnimationController _chartAnimController;

  @override
  void initState() {
    super.initState();
    _startProfileStream();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _startSensorStream();
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
        final doc = await FirebaseService.instance.userProfileStreamById(uid).first;
        if (doc.exists) {
          elderlies.add(UserModel.fromDoc(doc));
        }
      }

      if (mounted) {
        setState(() {
          _linkedElderlies = elderlies;
          if (_selectedElderly == null || !elderlies.any((e) => e.uid == _selectedElderly!.uid)) {
            _selectedElderly = elderlies.isNotEmpty ? elderlies.first : null;
            if (_selectedElderly != null) {
              _startAlertsStream();
            }
          }
          _profileLoaded = true;
        });
      }
    });
  }

  void _startAlertsStream() {
    if (_selectedElderly == null) return;
    
    // Listen to global alerts cache
    GlobalAlertCacheService.instance.alertsNotifier.addListener(_onAlertsChanged);
    _onAlertsChanged(); // initial fetch
  }

  void _onAlertsChanged() {
    if (!mounted || _selectedElderly == null) return;
    
    final today = DateTime.now();
    final cached = GlobalAlertCacheService.instance.alertsNotifier.value;
    
    final criticalCount = cached.where((alert) {
      if (alert.timestamp == null) return false;
      return alert.elderlyId == _selectedElderly!.uid &&
             alert.timestamp!.year == today.year &&
             alert.timestamp!.month == today.month &&
             alert.timestamp!.day == today.day &&
             alert.isHighPriority; // critical alerts today
    }).length;

    if (mounted && _alertCount != criticalCount) {
      setState(() => _alertCount = criticalCount);
    }
  }

  void _startSensorStream() {
    _sensorSub = FirebaseService.instance.sensorStream().listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          if (mounted) setState(() => isConnected = false);
          return;
        }

        final map = Map<String, dynamic>.from(data as Map);
        final sensorData = SensorData.fromMap(map);

        if (mounted) {          // Track motion
          if (sensorData.motion) {
            _lastMotionTime = DateTime.now();
            _movementDuration += const Duration(seconds: 5);
          } else {
            _inactivityTotal += const Duration(seconds: 5);
          }

          // Track sleep
          if (sensorData.isSleeping && _sleepStart == null) {
            _sleepStart = DateTime.now();
          } else if (!sensorData.isSleeping && _sleepStart != null) {
            _sleepDuration += DateTime.now().difference(_sleepStart!);
            _sleepStart = null;
          }

          // Heart rate history
          if (sensorData.heartRate > 0) {
            _hrHistory.add(sensorData.heartRate.toDouble());
            if (_hrHistory.length > _maxSamples) _hrHistory.removeAt(0);
          }

          // Breathing rate history
          if (sensorData.breathingRate > 0) {
            _brHistory.add(sensorData.breathingRate);
            if (_brHistory.length > _maxSamples) _brHistory.removeAt(0);
          }

          setState(() {
            _sensorData = sensorData;
            isConnected = true;
          });

          if (!_chartAnimController.isCompleted) {
            _chartAnimController.forward();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _sensorSub?.cancel();
    GlobalAlertCacheService.instance.alertsNotifier.removeListener(_onAlertsChanged);
    _tickTimer?.cancel();
    _chartAnimController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Dummy data for chart display when no real data yet
  List<double> get _displayHR => _hrHistory.length >= 3
      ? _hrHistory
      : (_isDayView
          ? [72, 75, 74, 78, 80, 76, 73]
          : [74, 76, 73, 77, 75, 78, 72]);

  List<double> get _displayBR => _brHistory.length >= 3
      ? _brHistory
      : (_isDayView
          ? [14, 15, 16, 17, 16, 15, 14]
          : [15, 14, 16, 15, 17, 16, 15]);

  // Smart insight message
  String get _insightMessage {
    if (_sensorData.isEmergency) return 'Alert: Fall detected — attention needed';
    if (_sensorData.isSleeping) return 'Sleep detected — monitoring continues';
    if (_movementDuration.inMinutes > 60) return 'Activity level is above average today';
    if (_inactivityTotal.inHours > 3) {
      return 'Slightly reduced movement compared to usual';
    }
    if (!_sensorData.motion && _lastMotionTime != null) {
      final idle = DateTime.now().difference(_lastMotionTime!).inMinutes;
      if (idle > 20) return 'Extended idle period — monitoring closely';
    }
    return 'Activity level is normal today';
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
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
              const Text('Link an elderly account to view activity history.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            _buildHeader(),
            const SizedBox(height: 20),

            // 2. Time Filter
            _buildTimeFilter(),
            const SizedBox(height: 20),

            // 3. Heart Rate Chart
            _buildHeartRateChart(),
            const SizedBox(height: 16),

            // 4. Breathing Rate Chart
            _buildBreathingChart(),
            const SizedBox(height: 20),

            // 5. Activity Summary Grid
            _buildSummaryGrid(),
            const SizedBox(height: 16),

            // 7. Insights Card
            _buildInsightsCard(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 1. HEADER
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? AppColors.success : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Health & Activity Insights',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_linkedElderlies.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.cardShadow,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UserModel>(
                value: _selectedElderly,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                onChanged: (UserModel? newValue) {
                  if (newValue != null && newValue.uid != _selectedElderly?.uid) {
                    setState(() {
                      _selectedElderly = newValue;
                      _startAlertsStream();
                    });
                  }
                },
                items: _linkedElderlies.map((UserModel user) {
                  return DropdownMenuItem<UserModel>(
                    value: user,
                    child: Text(user.name.isNotEmpty ? user.name : 'Elderly Profile'),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 2. TIME FILTER TOGGLE
  // ════════════════════════════════════════════════════════════════

  Widget _buildTimeFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(child: _filterButton('Day', _isDayView, () {
            HapticFeedback.selectionClick();
            setState(() => _isDayView = true);
          })),
          Expanded(child: _filterButton('Week', !_isDayView, () {
            HapticFeedback.selectionClick();
            setState(() => _isDayView = false);
          })),
        ],
      ),
    );
  }

  Widget _filterButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 3. HEART RATE CHART
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeartRateChart() {
    final data = _displayHR;
    final avg = data.isEmpty ? 0 : (data.reduce((a, b) => a + b) / data.length);
    final latest = data.isEmpty ? 0 : data.last;

    return _ChartCard(
      title: 'Heart Rate Trend',
      emoji: '❤️',
      valueText: '${latest.toStringAsFixed(0)} BPM',
      avgText: 'Avg: ${avg.toStringAsFixed(0)} BPM',
      child: SizedBox(
        height: 160,
        child: AnimatedBuilder(
          animation: _chartAnimController,
          builder: (context, _) {
            return CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _LineChartPainter(
                data: data,
                color: AppColors.danger,
                gradientColor: AppColors.danger,
                animValue: Curves.easeOutCubic
                    .transform(_chartAnimController.value),
                showDots: true,
                labels: _isDayView
                    ? ['6AM', '9AM', '12PM', '3PM', '6PM', '9PM', '12AM']
                    : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 4. BREATHING RATE CHART
  // ════════════════════════════════════════════════════════════════

  Widget _buildBreathingChart() {
    final data = _displayBR;
    final avg = data.isEmpty ? 0 : (data.reduce((a, b) => a + b) / data.length);
    final latest = data.isEmpty ? 0 : data.last;

    return _ChartCard(
      title: 'Breathing Rate',
      emoji: '🫁',
      valueText: '${latest.toStringAsFixed(0)} /min',
      avgText: 'Avg: ${avg.toStringAsFixed(0)} /min',
      child: SizedBox(
        height: 160,
        child: AnimatedBuilder(
          animation: _chartAnimController,
          builder: (context, _) {
            return CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _LineChartPainter(
                data: data,
                color: AppColors.success,
                gradientColor: AppColors.success,
                animValue: Curves.easeOutCubic
                    .transform(_chartAnimController.value),
                showDots: true,
                labels: _isDayView
                    ? ['6AM', '9AM', '12PM', '3PM', '6PM', '9PM', '12AM']
                    : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 5. ACTIVITY SUMMARY GRID (2x2)
  // ════════════════════════════════════════════════════════════════

  Widget _buildSummaryGrid() {
    final moveDur = _movementDuration.inMinutes > 0
        ? _formatDuration(_movementDuration)
        : '2h 30m';
    final inactDur = _inactivityTotal.inMinutes > 0
        ? _formatDuration(_inactivityTotal)
        : '5h';
    final sleepDur = _sleepDuration.inMinutes > 0
        ? _formatDuration(_sleepDuration + (_sleepStart != null ? DateTime.now().difference(_sleepStart!) : Duration.zero))
        : '6h 20m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Summary', Icons.dashboard_rounded),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                icon: Icons.directions_run_rounded,
                label: 'Movement',
                value: moveDur,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryTile(
                icon: Icons.timer_outlined,
                label: 'Inactivity',
                value: inactDur,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                icon: Icons.bedtime_rounded,
                label: 'Sleep',
                value: sleepDur,
                color: AppColors.primarySoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryTile(
                icon: Icons.warning_amber_rounded,
                label: 'Critical Alerts',
                value: '$_alertCount',
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  // ════════════════════════════════════════════════════════════════
  // 7. INSIGHTS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primarySoft.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded,
                color: AppColors.primarySoft, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Insight',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primarySoft,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    _insightMessage,
                    key: ValueKey(_insightMessage),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primarySoft,
                      height: 1.4,
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



  // ── Helpers ──────────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHART CARD WRAPPER
// ══════════════════════════════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String valueText;
  final String avgText;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.emoji,
    required this.valueText,
    required this.avgText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    avgText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LINE CHART PAINTER — smooth curves with animated reveal
// ══════════════════════════════════════════════════════════════════════════════

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color gradientColor;
  final double animValue;
  final bool showDots;
  final List<String> labels;

  _LineChartPainter({
    required this.data,
    required this.color,
    required this.gradientColor,
    required this.animValue,
    this.showDots = false,
    this.labels = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const topPad = 10.0;
    const bottomPad = 24.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width;

    final minVal = data.reduce(math.min) - 2;
    final maxVal = data.reduce(math.max) + 2;
    final range = maxVal - minVal;
    if (range == 0) return;

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;

    for (int i = 0; i <= 3; i++) {
      final y = topPad + (chartHeight * i / 3);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Calculate points
    final step = chartWidth / (data.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = topPad +
          chartHeight -
          ((data[i] - minVal) / range) * chartHeight;
      points.add(Offset(x, y));
    }

    // Create smooth path using cubic Bezier
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cpx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cpx, p0.dy, cpx, p1.dy, p1.dx, p1.dy);
    }

    // Clip to animValue
    canvas.clipRect(Rect.fromLTWH(0, 0, chartWidth * animValue, size.height));

    // Fill gradient
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, topPad + chartHeight);
    fillPath.lineTo(points.first.dx, topPad + chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gradientColor.withValues(alpha: 0.15),
          gradientColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Data dots
    if (showDots) {
      final dotPaint = Paint()..color = color;
      final dotBorder = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      for (final point in points) {
        if (point.dx <= chartWidth * animValue) {
          canvas.drawCircle(point, 4, dotPaint);
          canvas.drawCircle(point, 4, dotBorder);
        }
      }
    }

    // Reset clip for labels
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // X-axis labels
    if (labels.isNotEmpty && labels.length == data.length) {
      final textStyle = TextStyle(
        color: const Color(0xFF9CA3AF),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      );

      for (int i = 0; i < labels.length; i++) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(points[i].dx - tp.width / 2,
              size.height - bottomPad + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.animValue != animValue ||
      old.data.length != data.length ||
      (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}

