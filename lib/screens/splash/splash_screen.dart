import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'welcome_screen.dart';
import '../elderly/elderly_dashboard.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../emergency/emergency_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // Use addPostFrameCallback to ensure context is fully available
    // before attempting navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigate();
    });
  }

  Future<void> _navigate() async {
    // Show splash branding for at least 2 seconds
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    debugPrint('🔍 Splash: currentUser = ${user?.uid ?? "null"}');

    if (user != null) {
      try {
        // Timeout after 3 seconds — never freeze the splash screen
        final doc = await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 3));

        if (!mounted) return;

        if (doc.exists) {
          final role = (doc.data()?['role'] as String? ?? '').toLowerCase();
          debugPrint('🔍 Splash: user found, role = $role → navigating to dashboard');
          _navigateByRole(role);
          return;
        } else {
          debugPrint('🔍 Splash: user doc does NOT exist → WelcomeScreen');
        }
      } on TimeoutException {
        debugPrint('🔍 Splash: Firestore timeout → WelcomeScreen');
      } catch (e) {
        debugPrint('🔍 Splash: auth check error ($e) → WelcomeScreen');
      }
    } else {
      debugPrint('🔍 Splash: no user logged in → WelcomeScreen');
    }

    // Fallback: always navigate to WelcomeScreen
    if (!mounted) return;
    _navigateToWelcome();
  }

  void _navigateToWelcome() {
    debugPrint('🔍 Splash: → Navigating to WelcomeScreen');
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _navigateByRole(String role) {
    Widget destination;
    switch (role) {
      case 'caregiver':
        destination = const CaregiverDashboard();
        break;
      case 'emergency':
        destination = const EmergencyDashboard();
        break;
      default:
        destination = const ElderlyDashboard();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium Consistent Circular Logo
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.asset(
                          'assets/images/safenest_logo.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.favorite_rounded,
                                  size: 32, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Name
                  Text(
                    AppConstants.appName,
                    style:
                        Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                  ),

                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    AppConstants.appTagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}