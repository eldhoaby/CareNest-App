import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../models/sensor_data_model.dart';
import '../../models/alert_model.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/sensor_tile.dart';
import '../auth/role_selection_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _tab = 0;

  String userName = '';
  String userEmail = '';
  String userId = '';
  String elderlyUid = '';
  String elderlyName = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await FirebaseService.instance.getUserProfile();

      if (profile != null && mounted) {
        setState(() {
          userName = profile['name'] ?? '';
          userEmail = profile['email'] ?? '';
          userId = profile['uid'] ??
              FirebaseService.instance.currentUid ?? '';
          elderlyUid = profile['linkedElderlyUid'] ?? '';
        });

        // Get elderly name
        if (elderlyUid.isNotEmpty) {
          final elderly =
              await FirebaseService.instance.getUserById(elderlyUid);
          if (elderly != null && mounted) {
            setState(() => elderlyName = elderly.name);
          }
        }
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _logout() async {
    await FirebaseService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0FDF4),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF22C55E)),
        ),
      );
    }

    final tabs = [
      _CGHomeTab(
        userName: userName,
        elderlyUid: elderlyUid,
        elderlyName: elderlyName,
      ),
      _CGAlertsTab(elderlyUid: elderlyUid, userId: userId),
      _CGSensorsTab(),
      _CGProfileTab(
        userName: userName,
        userEmail: userEmail,
        elderlyName: elderlyName,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: _appBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: tabs[_tab],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              Text(
                'Caregiver · ${userName.isEmpty ? userEmail.split("@")[0] : userName}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _bottomNav() {
    return BottomNavigationBar(
      currentIndex: _tab,
      selectedItemColor: const Color(0xFF22C55E),
      unselectedItemColor: Colors.grey[400],
      backgroundColor: Colors.white,
      elevation: 16,
      type: BottomNavigationBarType.fixed,
      onTap: (i) {
        HapticFeedback.selectionClick();
        setState(() => _tab = i);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Overview',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications_rounded),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sensors_outlined),
          activeIcon: Icon(Icons.sensors_rounded),
          label: 'Sensors',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════════

class _CGHomeTab extends StatefulWidget {
  final String userName;
  final String elderlyUid;
  final String elderlyName;

  const _CGHomeTab({
    required this.userName,
    required this.elderlyUid,
    required this.elderlyName,
  });

  @override
  State<_CGHomeTab> createState() => _CGHomeTabState();
}

class _CGHomeTabState extends State<_CGHomeTab> {
  StreamSubscription? _sensorSub;
  SensorData _sensorData = SensorData.empty;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _sensorSub = FirebaseService.instance.sensorStream().listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          if (mounted) setState(() => isConnected = false);
          return;
        }
        final map = Map<String, dynamic>.from(data as Map);
        if (mounted) {
          setState(() {
            _sensorData = SensorData.fromMap(map);
            isConnected = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Hello, ${widget.userName.isEmpty ? "Caregiver" : widget.userName} 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.elderlyName.isEmpty
                ? 'No elderly linked yet'
                : 'Monitoring: ${widget.elderlyName}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),

          const SizedBox(height: 20),

          // Status Card
          _buildStatusCard(),

          const SizedBox(height: 20),

          // Vital Cards Row
          const Text('Health Vitals',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          Row(
            children: [
              _vitalCard('Heart Rate', '${_sensorData.heartRate} bpm',
                  Icons.favorite, const Color(0xFFEF4444)),
              const SizedBox(width: 12),
              _vitalCard('SpO₂', '${_sensorData.spo2}%', Icons.air,
                  const Color(0xFF3B82F6)),
              const SizedBox(width: 12),
              _vitalCard('Breathing', '${_sensorData.breathingRate.toStringAsFixed(0)}/min',
                  Icons.air_outlined, const Color(0xFF8B5CF6)),
            ],
          ),

          const SizedBox(height: 20),

          // Connection Status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF22C55E)
                      : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected
                    ? 'Sensor Connected • Live Data'
                    : 'Waiting for sensor data...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isConnected
                      ? const Color(0xFF22C55E)
                      : Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Alerts Preview
          if (widget.elderlyUid.isNotEmpty) ...[
            const Text('Recent Alerts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _buildRecentAlerts(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _sensorData.statusLabel;
    Color bgColor;
    Color iconColor;
    IconData icon;
    String subtitle;

    if (_sensorData.isEmergency) {
      bgColor = const Color(0xFFFEE2E2);
      iconColor = const Color(0xFFEF4444);
      icon = Icons.warning_rounded;
      subtitle = 'Immediate attention required!';
    } else if (status == 'Active') {
      bgColor = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF22C55E);
      icon = Icons.check_circle;
      subtitle = 'Everything looks normal';
    } else if (status == 'Inactive') {
      bgColor = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFF59E0B);
      icon = Icons.schedule;
      subtitle = 'No recent activity detected';
    } else {
      bgColor = const Color(0xFFE0E7FF);
      iconColor = const Color(0xFF6366F1);
      icon = Icons.info_outline;
      subtitle = 'Patient is away from sensor range';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Status: $status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.instance.alertsStream(widget.elderlyUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[400]),
                const SizedBox(width: 12),
                const Text('No alerts — all clear!'),
              ],
            ),
          );
        }

        // Show last 3
        final recentDocs = docs.take(3).toList();
        return Column(
          children: recentDocs.map((doc) {
            final alert = AlertModel.fromDoc(doc);
            return AlertCard(
              alert: alert,
              onResolve: alert.isActive
                  ? () => FirebaseService.instance.resolveAlert(doc.id)
                  : null,
              showActions: alert.isActive,
            );
          }).toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ALERTS TAB
// ═══════════════════════════════════════════════════════════════

class _CGAlertsTab extends StatefulWidget {
  final String elderlyUid;
  final String userId;

  const _CGAlertsTab({required this.elderlyUid, required this.userId});

  @override
  State<_CGAlertsTab> createState() => _CGAlertsTabState();
}

class _CGAlertsTabState extends State<_CGAlertsTab> {
  String _filter = 'all'; // all, active, resolved

  @override
  Widget build(BuildContext context) {
    if (widget.elderlyUid.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No elderly user linked',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Ask elderly to share their invite code',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              _filterChip('All', 'all'),
              const SizedBox(width: 8),
              _filterChip('Active', 'active'),
              const SizedBox(width: 8),
              _filterChip('Resolved', 'resolved'),
            ],
          ),
        ),

        // Alert list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.instance.alertsStream(widget.elderlyUid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var alerts = snapshot.data!.docs
                  .map((doc) => AlertModel.fromDoc(doc))
                  .toList();

              // Apply filter
              if (_filter == 'active') {
                alerts = alerts
                    .where((a) => a.status == AlertStatus.active)
                    .toList();
              } else if (_filter == 'resolved') {
                alerts = alerts
                    .where((a) => a.status == AlertStatus.resolved)
                    .toList();
              }

              if (alerts.isEmpty) {
                return Center(
                  child: Text('No ${_filter == "all" ? "" : _filter} alerts',
                      style: const TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: alerts.length,
                itemBuilder: (_, i) {
                  final alert = alerts[i];
                  return AlertCard(
                    alert: alert,
                    onRespond: alert.isActive
                        ? () => FirebaseService.instance
                            .respondToAlert(
                                snapshot.data!.docs[i].id, widget.userId)
                        : null,
                    onResolve: alert.isActive
                        ? () => FirebaseService.instance
                            .resolveAlert(snapshot.data!.docs[i].id)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF22C55E)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SENSORS TAB
// ═══════════════════════════════════════════════════════════════

class _CGSensorsTab extends StatefulWidget {
  const _CGSensorsTab();

  @override
  State<_CGSensorsTab> createState() => _CGSensorsTabState();
}

class _CGSensorsTabState extends State<_CGSensorsTab> {
  StreamSubscription? _sensorSub;
  SensorData _data = SensorData.empty;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _sensorSub = FirebaseService.instance.sensorStream().listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          if (mounted) setState(() => isConnected = false);
          return;
        }
        final map = Map<String, dynamic>.from(data as Map);
        if (mounted) {
          setState(() {
            _data = SensorData.fromMap(map);
            isConnected = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sensor Diagnostics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFF22C55E) : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Live Data Feed' : 'Waiting for data...',
                style: TextStyle(
                  fontSize: 13,
                  color: isConnected ? const Color(0xFF22C55E) : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              SensorTile(
                label: 'Presence',
                value: _data.presence ? 'Detected' : 'None',
                icon: Icons.person,
                color: _data.presence ? const Color(0xFF22C55E) : Colors.grey,
              ),
              SensorTile(
                label: 'Motion',
                value: _data.motion ? 'Moving' : 'Still',
                icon: Icons.directions_walk,
                color: _data.motion ? const Color(0xFF3B82F6) : Colors.grey,
              ),
              SensorTile(
                label: 'Posture',
                value: _data.postureLabel,
                icon: Icons.accessibility,
                color: _data.isEmergency
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
                isWarning: _data.isEmergency,
              ),
              SensorTile(
                label: 'Door',
                value: _data.doorOpen ? 'Open' : 'Closed',
                icon: Icons.door_front_door,
                color: _data.doorOpen
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF22C55E),
              ),
              SensorTile(
                label: 'Heart Rate',
                value: '${_data.heartRate} bpm',
                icon: Icons.favorite,
                color: const Color(0xFFEC4899),
              ),
              SensorTile(
                label: 'SpO₂',
                value: '${_data.spo2}%',
                icon: Icons.air,
                color: const Color(0xFF3B82F6),
              ),
              SensorTile(
                label: 'Breathing',
                value: '${_data.breathingRate.toStringAsFixed(0)}/min',
                icon: Icons.air_outlined,
                color: const Color(0xFF8B5CF6),
              ),
              SensorTile(
                label: 'Distance',
                value: '${_data.distance.toStringAsFixed(1)} cm',
                icon: Icons.straighten,
                color: const Color(0xFFF59E0B),
              ),
              SensorTile(
                label: 'Uptime',
                value: '${_data.uptimeMs ~/ 1000}s',
                icon: Icons.timer,
                color: const Color(0xFF6366F1),
              ),
              SensorTile(
                label: 'Fall',
                value: _data.fallDetected ? 'DETECTED' : 'None',
                icon: Icons.personal_injury,
                color: _data.fallDetected
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
                isWarning: _data.fallDetected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILE TAB
// ═══════════════════════════════════════════════════════════════

class _CGProfileTab extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String elderlyName;
  final VoidCallback onLogout;

  const _CGProfileTab({
    required this.userName,
    required this.userEmail,
    required this.elderlyName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.08),
                  const Color(0xFF16A34A).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  userName.isEmpty ? userEmail : userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(userEmail,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CAREGIVER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF22C55E),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Linked elderly info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.elderly,
                      color: Color(0xFF3B82F6), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Linked Elderly',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        elderlyName.isEmpty
                            ? 'Not linked yet'
                            : elderlyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  elderlyName.isEmpty
                      ? Icons.link_off
                      : Icons.link,
                  color: elderlyName.isEmpty
                      ? Colors.grey
                      : const Color(0xFF22C55E),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}