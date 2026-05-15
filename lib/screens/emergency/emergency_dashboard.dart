import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/alert_notification_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/unseen_alert_service.dart';
import '../auth/role_selection_screen.dart';
import '../caregiver/caregiver_alert_tab.dart';
import 'emergency_history_tab.dart';
import 'emergency_profile_tab.dart';
import '../../widgets/global_loader.dart';

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
    AlertNotificationService.instance.reset();
    await UnseenAlertService.instance.reset();
    await FirebaseService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const GlobalLoader(isFullScreen: true);
    }

    final tabs = [
      const CaregiverAlertTab(isEmergency: true),
      EmergencyHistoryTab(userId: userId),
      EmergencyProfileTab(
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: tabs[_tab],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.warning_amber_rounded, Icons.warning_rounded, 'Active', 0),
              _navItem(Icons.history_rounded, Icons.history_rounded, 'History', 1),
              _navItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.danger.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? AppColors.danger : AppColors.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
