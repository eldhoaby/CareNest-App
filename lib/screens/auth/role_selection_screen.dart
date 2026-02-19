import 'package:flutter/material.dart';
import '../../widgets/role_card.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToLogin(String role) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LoginScreen(role: role),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF5F7FA),
                Color(0xFFE3ECF7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [

                  const SizedBox(height: 40),

                  // 🔷 Header
                  const Text(
                    "Choose Your Access",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Care That Never Sleeps.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // 👥 Role Cards
                  Expanded(
                    child: Column(
                      children: [

                        RoleCard(
                          title: 'Elderly / Patient',
                          subtitle: 'Personal safety monitoring',
                          icon: Icons.person,
                          color: Colors.blue,
                          onTap: () => _navigateToLogin("Elderly"),
                        ),

                        const SizedBox(height: 24),

                        RoleCard(
                          title: 'Caregiver / Family',
                          subtitle: 'Monitor loved ones & receive alerts',
                          icon: Icons.family_restroom,
                          color: Colors.green,
                          onTap: () => _navigateToLogin("Caregiver"),
                        ),

                        const SizedBox(height: 24),

                        RoleCard(
                          title: 'Emergency Services',
                          subtitle: 'Respond instantly to safety alerts',
                          icon: Icons.local_hospital,
                          color: Colors.red,
                          onTap: () => _navigateToLogin("Emergency"),
                        ),

                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
