import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/alert_service.dart';
import '../../models/sensor_data_model.dart';
import '../../widgets/sensor_tile.dart';
import '../../widgets/animated_sos_button.dart';

class ElderlyHomeTab extends StatefulWidget {
  final String userName;
  final String userId;

  const ElderlyHomeTab({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<ElderlyHomeTab> createState() => _ElderlyHomeTabState();
}

class _ElderlyHomeTabState extends State<ElderlyHomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  SensorData _sensorData = SensorData.empty;
  bool isConnected = false;
  bool isLoading = true;
  DateTime? lastUpdated;

  StreamSubscription? _sensorSub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSensorStream();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🆘 Emergency SOS sent!'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('SOS error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sensorSub?.cancel();
    super.dispose();
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 12),
            _buildConnectionStatus(),
            const SizedBox(height: 12),
            _buildOverallStatusBanner(),
            const SizedBox(height: 24),
            _buildSectionLabel('📡 Sensor Data'),
            const SizedBox(height: 12),
            _buildSensorGrid(),
            const SizedBox(height: 24),
            _buildSectionLabel('❤️ Health Vitals'),
            const SizedBox(height: 12),
            _buildHealthGrid(),
            const SizedBox(height: 30),
            // SOS Button
            Center(
              child: AnimatedSOSButton(onPressed: _sendSOS, size: 180),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Press SOS if you need immediate help',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            if (lastUpdated != null) ...[
              const SizedBox(height: 16),
              _buildLastUpdated(),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.08),
            const Color(0xFF3B82F6).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.userName.isEmpty ? 'User' : widget.userName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _sensorData.vitalsStable
                      ? 'All vitals stable ✓'
                      : '⚠️ Vitals warning detected',
                  style: TextStyle(
                    fontSize: 14,
                    color: _sensorData.vitalsStable
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Icon(
              _sensorData.vitalsStable
                  ? Icons.favorite
                  : Icons.warning_amber_rounded,
              size: 44,
              color: _sensorData.vitalsStable
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? const Color(0xFF22C55E) : Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isConnected ? 'Sensor Connected • Live Data' : 'Waiting for sensor data...',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isConnected ? const Color(0xFF22C55E) : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatusBanner() {
    final isEmergency = _sensorData.isEmergency;
    final status = _sensorData.statusLabel;

    Color bgColor;
    Color textColor;
    IconData icon;

    if (isEmergency) {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      icon = Icons.warning_rounded;
    } else if (status == 'Active') {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF22C55E);
      icon = Icons.verified_rounded;
    } else {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFF59E0B);
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $status',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: 15,
                  ),
                ),
                if (isEmergency)
                  Text(
                    'Caregiver and emergency services notified',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSensorGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        SensorTile(
          label: 'Presence',
          value: _sensorData.presence ? 'Detected' : 'None',
          icon: Icons.person,
          color: _sensorData.presence
              ? const Color(0xFF22C55E)
              : Colors.grey,
        ),
        SensorTile(
          label: 'Motion',
          value: _sensorData.motion ? 'Moving' : 'Still',
          icon: Icons.directions_walk,
          color: _sensorData.motion
              ? const Color(0xFF3B82F6)
              : Colors.grey,
        ),
        SensorTile(
          label: 'Posture',
          value: _sensorData.postureLabel,
          icon: Icons.accessibility,
          color: _sensorData.isEmergency
              ? const Color(0xFFEF4444)
              : const Color(0xFF22C55E),
          isWarning: _sensorData.isEmergency,
        ),
        SensorTile(
          label: 'Door',
          value: _sensorData.doorOpen ? 'Open' : 'Closed',
          icon: Icons.door_front_door,
          color: _sensorData.doorOpen
              ? const Color(0xFFF59E0B)
              : const Color(0xFF22C55E),
        ),
      ],
    );
  }

  Widget _buildHealthGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        SensorTile(
          label: 'Heart Rate',
          value: '${_sensorData.heartRate} bpm',
          icon: Icons.favorite,
          color: _sensorData.heartRate > 100
              ? const Color(0xFFEF4444)
              : const Color(0xFFEC4899),
          isWarning: _sensorData.heartRate > 100,
        ),
        SensorTile(
          label: 'SpO₂',
          value: '${_sensorData.spo2}%',
          icon: Icons.air,
          color: _sensorData.spo2 < 94
              ? const Color(0xFFEF4444)
              : const Color(0xFF3B82F6),
          isWarning: _sensorData.spo2 > 0 && _sensorData.spo2 < 94,
        ),
        SensorTile(
          label: 'Breathing',
          value: '${_sensorData.breathingRate.toStringAsFixed(0)}/min',
          icon: Icons.air_outlined,
          color: const Color(0xFF8B5CF6),
        ),
        SensorTile(
          label: 'Distance',
          value: '${_sensorData.distance.toStringAsFixed(1)} cm',
          icon: Icons.straighten,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildLastUpdated() {
    final t = lastUpdated!;
    final formatted =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    return Center(
      child: Text(
        'Last updated: $formatted',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    );
  }
}