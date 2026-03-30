import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _goToLogin(BuildContext context, String role) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => LoginScreen(role: role),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          // Decorative Gradient Header
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            child: Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A7FFF), Color(0xFF6AA6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(200),
                  bottomRight: Radius.circular(200),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  const Text(
                    'Choose Your Access',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Select your role to continue',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),

                  const SizedBox(height: 60),

                  _roleCard(
                    context,
                    role: 'elderly',
                    title: 'Elderly / Patient',
                    subtitle: 'Personal safety monitoring',
                    icon: Icons.person_outline,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFE8F0FF),
                  ),

                  const SizedBox(height: 18),

                  _roleCard(
                    context,
                    role: 'caregiver',
                    title: 'Caregiver / Family',
                    subtitle: 'Monitor loved ones & receive alerts',
                    icon: Icons.favorite_outline,
                    color: const Color(0xFF22C55E),
                    bgColor: const Color(0xFFEAFBF1),
                  ),

                  const SizedBox(height: 18),

                  _roleCard(
                    context,
                    role: 'emergency',
                    title: 'Emergency Services',
                    subtitle: 'Respond instantly to safety alerts',
                    icon: Icons.local_hospital_outlined,
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFFF1F1),
                  ),

                  const Spacer(),

                  Text(
                    '${AppConstants.appName} AAL System',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _goToLogin(context, role),
        child: Container(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}