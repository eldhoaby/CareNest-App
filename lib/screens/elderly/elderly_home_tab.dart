import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/status_card.dart';
import 'package:aal_app/core/theme/app_theme.dart';

class ElderlyHomeTab extends StatefulWidget {
  final String userName;

  const ElderlyHomeTab({super.key, required this.userName});

  @override
  State<ElderlyHomeTab> createState() => _ElderlyHomeTabState();
}

class _ElderlyHomeTabState extends State<ElderlyHomeTab>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Timer _timer;

  int heartRate = 72;
  int oxygen = 98;
  bool presence = true;
  bool motion = true;
  double distance = 1.2;
  bool doorClosed = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Simulated sensor updates (Replace with real Firestore stream later)
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      setState(() {
        heartRate = 65 + Random().nextInt(25);
        oxygen = 94 + Random().nextInt(6);
        presence = Random().nextBool();
        motion = Random().nextBool();
        distance = 0.5 + Random().nextDouble() * 1.5;
        doorClosed = Random().nextBool();
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer.cancel();
    super.dispose();
  }

  bool get isStable => heartRate < 95 && oxygen > 94;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 👋 Welcome Section
            _buildWelcomeCard(),

            const SizedBox(height: 24),

            // 🟢 Overall Status
            _buildOverallStatusBanner(),

            const SizedBox(height: 32),

            // 📡 Sensor Grid
            _buildSensorGrid(),

            const SizedBox(height: 32),

            // ❤️ Health Vitals
            _buildHealthVitalsRow(),
          ],
        ),
      ),
    );
  }

  // =============================
  // Welcome Card
  // =============================

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: SafeNestTheme.glassCard(Colors.blue),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$greeting 👋",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.userName.isEmpty ? "User" : widget.userName,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isStable
                      ? "All vitals stable"
                      : "Vitals warning detected",
                  style: TextStyle(
                    fontSize: 15,
                    color: isStable ? Colors.green : Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Icon(
              isStable
                  ? Icons.favorite
                  : Icons.warning_amber_rounded,
              size: 48,
              color: isStable ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // Overall Status Banner
  // =============================

  Widget _buildOverallStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isStable ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStable ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isStable ? Icons.verified : Icons.warning,
            color: isStable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isStable
                  ? "System operating normally"
                  : "Health anomaly detected. Please check vitals.",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isStable
                    ? Colors.green[800]
                    : Colors.red[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // Sensor Grid
  // =============================

  Widget _buildSensorGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        StatusCard(
          label: 'Presence',
          value: presence ? 'ACTIVE' : 'ABSENT',
          color: presence ? Colors.green : Colors.red,
          icon: presence ? Icons.person : Icons.person_off,
        ),
        StatusCard(
          label: 'Motion',
          value: motion ? 'MOVING' : 'STILL',
          color: motion ? Colors.blue : Colors.orange,
          icon: Icons.directions_walk,
        ),
        StatusCard(
          label: 'Distance',
          value: '${distance.toStringAsFixed(1)} m',
          color: distance < 0.7 ? Colors.red : Colors.green,
          icon: Icons.straighten,
          isWarning: distance < 0.7,
        ),
        StatusCard(
          label: 'Door',
          value: doorClosed ? 'CLOSED' : 'OPEN',
          color: doorClosed ? Colors.green : Colors.orange,
          icon: doorClosed
              ? Icons.meeting_room
              : Icons.door_back_door,
          isWarning: !doorClosed,
        ),
      ],
    );
  }

  // =============================
  // Health Row
  // =============================

  Widget _buildHealthVitalsRow() {
    return Row(
      children: [
        Expanded(
          child: StatusCard(
            label: 'Heart Rate',
            value: '$heartRate bpm',
            color: heartRate > 90 ? Colors.red : Colors.green,
            icon: Icons.favorite,
            isWarning: heartRate > 90,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatusCard(
            label: 'Oxygen',
            value: '$oxygen%',
            color: oxygen < 96 ? Colors.red : Colors.green,
            icon: Icons.air,
            isWarning: oxygen < 96,
          ),
        ),
      ],
    );
  }
}
