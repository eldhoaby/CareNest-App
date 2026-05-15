import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/alert_notification_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/global_alert_cache_service.dart';
import '../../core/services/unseen_alert_service.dart';
import '../auth/role_selection_screen.dart';
import 'elderly_home_tab.dart';
import 'elderly_alerts_tab.dart';
import 'elderly_activity_tab.dart';
import 'elderly_profile_tab.dart';
import '../../widgets/global_loader.dart';

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

        AlertService.instance.startMonitoring(
          elderlyUid: userId,
          elderlyName: userName,
        );
        
        // Start listening to the global cache for realtime sync
        GlobalAlertCacheService.instance.startListening([userId]);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _logout() async {
    AlertService.instance.stopMonitoring();
    GlobalAlertCacheService.instance.stopListening();
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
    setState(() => _currentTab = index);
  }

  @override
  void dispose() {
    AlertService.instance.stopMonitoring();
    GlobalAlertCacheService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const GlobalLoader(isFullScreen: true);
    }

    final tabs = [
      ElderlyHomeTab(
        userName: userName,
        userId: userId,
        onNavigateToAlerts: () => _switchTab(1),
        onNavigateToActivity: () => _switchTab(2),
      ),
      ElderlyAlertsTab(userId: userId),
      ElderlyActivityTab(userId: userId),
      ElderlyProfileTab(
        userName: userName,
        userEmail: userEmail,
        onLogout: _logout,
      ),
    ];

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
          child: tabs[_currentTab],
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
                  _navItem(Icons.notifications_outlined,
                      Icons.notifications_rounded, 'Alerts', 1),
                  _navItem(Icons.timeline_outlined, Icons.timeline_rounded,
                      'Activity', 2),
                  _navItem(
                      Icons.person_outline, Icons.person_rounded, 'Profile', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      IconData icon, IconData activeIcon, String label, int index) {
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