import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../auth/role_selection_screen.dart';
import 'emergency_alerts_tab.dart';
import 'emergency_history_tab.dart';
import 'emergency_profile_tab.dart';

class EmergencyDashboard extends StatefulWidget {
  const EmergencyDashboard({super.key});

  @override
  State<EmergencyDashboard> createState() => _EmergencyDashboardState();
}

class _EmergencyDashboardState extends State<EmergencyDashboard> {
  int _tab = 0;

  String userName = '';
  String userEmail = '';
  String userId = '';
  String organization = '';
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
          organization = profile['organizationName'] ?? '';
        });
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
        backgroundColor: Color(0xFFFFF5F5),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEF4444)),
        ),
      );
    }

    final tabs = [
      EmergencyAlertsTab(userId: userId),
      EmergencyHistoryTab(userId: userId),
      EmergencyProfileTab(
        userName: userName,
        userEmail: userEmail,
        organization: organization,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEF4444),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_hospital,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '${AppConstants.appName} Emergency',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  organization.isEmpty ? 'Emergency Services' : organization,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: tabs[_tab],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFEF4444),
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
            icon: Icon(Icons.warning_outlined),
            activeIcon: Icon(Icons.warning_rounded),
            label: 'Active',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
