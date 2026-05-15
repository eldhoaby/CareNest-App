import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/alert_notification_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/global_alert_cache_service.dart';
import '../../core/services/unseen_alert_service.dart';
import '../auth/role_selection_screen.dart';

import 'caregiver_home_tab.dart';
import 'caregiver_alert_tab.dart';
import 'caregiver_activity_tab.dart';
import 'caregiver_profile_tab.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _currentTab = 0;
  final ValueNotifier<int> _activeAlertsCount = ValueNotifier<int>(0);

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      CaregiverHomeTab(
        onSwitchTab: _switchTab,
        activeAlertsCount: _activeAlertsCount,
      ),
      const CaregiverAlertTab(),
      const CaregiverActivityTab(),
      CaregiverProfileTab(
        onLogout: () async {
          GlobalAlertCacheService.instance.stopListening();
          AlertNotificationService.instance.reset();
          await UnseenAlertService.instance.reset();
          await FirebaseService.instance.logout();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            (route) => false,
          );
        },
      ),
    ];
  }

  @override
  void dispose() {
    GlobalAlertCacheService.instance.stopListening();
    _activeAlertsCount.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentTab),
          child: _tabs[_currentTab],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
                  _navItem(Icons.notifications_outlined, Icons.notifications_rounded, 'Alerts', 1),
                  _navItem(Icons.analytics_outlined, Icons.analytics_rounded, 'Activity', 2),
                  _navItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 22,
                    color: isActive ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                if (index == 1) // Only for 'Alerts' tab
                  ValueListenableBuilder<int>(
                    valueListenable: UnseenAlertService.instance.unseenCount,
                    builder: (context, count, _) {
                      if (count <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}