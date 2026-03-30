import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/alert_service.dart';
import '../auth/role_selection_screen.dart';
import 'elderly_home_tab.dart';
import 'elderly_alerts_tab.dart';
import 'elderly_profile_tab.dart';

class ElderlyDashboard extends StatefulWidget {
  const ElderlyDashboard({super.key});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard> {
  int _currentTab = 0;

  String userName = '';
  String userEmail = '';
  String userId = '';
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
              FirebaseService.instance.currentUid ??
              '';
        });

        // Start alert monitoring
        AlertService.instance.startMonitoring(
          elderlyUid: userId,
          elderlyName: userName,
        );
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _logout() async {
    AlertService.instance.stopMonitoring();
    await FirebaseService.instance.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    AlertService.instance.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = [
      ElderlyHomeTab(userName: userName, userId: userId),
      ElderlyAlertsTab(userId: userId),
      ElderlyProfileTab(
        userName: userName,
        userEmail: userEmail,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
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
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 20,
              ),
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
                  'Elderly · ${userName.isEmpty ? "User" : userName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_currentTab),
          child: tabs[_currentTab],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey[400],
        backgroundColor: Colors.white,
        elevation: 16,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentTab = i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
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