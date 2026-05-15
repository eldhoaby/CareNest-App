import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import 'register_screen.dart';
import '../elderly/elderly_dashboard.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../emergency/emergency_dashboard.dart';
import '../setup/elderly_setup_screen.dart';
import '../setup/caregiver_setup_screen.dart';
import '../setup/emergency_setup_screen.dart';
import '../../widgets/global_loader.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final identityCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  // Real-time validation
  bool _identityValid = false;
  bool _passwordValid = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    identityCtrl.addListener(_validate);
    passwordCtrl.addListener(_validate);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    
    _animCtrl.forward();
  }

  void _validate() {
    final email = identityCtrl.text.trim();
    final isEmail = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(email);

    setState(() {
      _identityValid = isEmail;
      _passwordValid = passwordCtrl.text.length >= 6;
    });
  }

  bool get _formIsValid => _identityValid && _passwordValid;

  @override
  void dispose() {
    _animCtrl.dispose();
    identityCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || !_formIsValid) return;

    setState(() => _loading = true);

    try {
      final email = identityCtrl.text.trim();
      final password = passwordCtrl.text.trim();

      await FirebaseService.instance.loginUser(
        email: email,
        password: password,
      );

      // Fetch profile and validate role
      final profile = await FirebaseService.instance.getUserProfile();
      if (profile == null) {
        throw FirebaseAuthException(code: 'user-data-missing');
      }

      final userRole = (profile['role'] as String? ?? '').toLowerCase();

      if (userRole != widget.role.toLowerCase()) {
        await FirebaseService.instance.logout();
        setState(() => _loading = false);
        _showSnack(
          'You are registered as ${userRole.toUpperCase()}, not ${widget.role.toUpperCase()}.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      // Check profileComplete → setup or dashboard
      final profileComplete = profile['profileComplete'] == true;

      if (!profileComplete) {
        _navigateToSetup(userRole);
      } else {
        _navigateToDashboard(userRole);
      }

      // Register FCM in background
      NotificationService.instance.registerTokenAfterLogin(userRole);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      _showSnack(_friendlyError(e.code), isError: true);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showSnack('Login failed. Please try again.', isError: true);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'user-data-missing':
        return 'Profile data missing. Please register again.';
      default:
        return 'Login failed ($code)';
    }
  }

  void _navigateToSetup(String role) {
    Widget destination;
    switch (role) {
      case 'caregiver':
        destination = const CaregiverSetupScreen();
        break;
      case 'emergency':
        destination = const EmergencySetupScreen();
        break;
      default:
        destination = const ElderlySetupScreen();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }

  void _navigateToDashboard(String role) {
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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Premium Decorative Blurs
          Positioned(
            top: -80,
            right: -70,
            child: _glowCircle(280, AppColors.primarySoft.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: -60,
            left: -80,
            child: _glowCircle(240, AppColors.secondarySoft.withValues(alpha: 0.10)),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 32),
                        _buildCard(),
                        const SizedBox(height: 24),
                        _buildRegisterLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          if (_loading)
            const GlobalLoader(isFullScreen: true),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final roleIcon = widget.role == 'elderly'
        ? Icons.person_rounded
        : widget.role == 'caregiver'
            ? Icons.group_rounded
            : Icons.local_hospital_rounded;
            
    final roleGradient = widget.role == 'elderly'
        ? AppColors.primaryGradient
        : widget.role == 'caregiver'
            ? AppColors.secondaryGradient
            : AppColors.emergencyGradient;

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: roleGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: roleGradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(roleIcon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.role[0].toUpperCase()}${widget.role.substring(1)} Portal',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email
            TextFormField(
              controller: identityCtrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined, size: 22),
                suffixIcon: identityCtrl.text.isNotEmpty
                    ? Icon(
                        _identityValid
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _identityValid
                            ? AppColors.success
                            : AppColors.danger,
                        size: 20,
                      )
                    : null,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                final trimmed = v.trim();
                if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(trimmed)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Password
            TextFormField(
              controller: passwordCtrl,
              obscureText: _obscure,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: const TextStyle(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Minimum 6 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (passwordCtrl.text.isNotEmpty)
                      Icon(
                        _passwordValid
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _passwordValid
                            ? AppColors.success
                            : AppColors.danger,
                        size: 20,
                      ),
                    IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          key: ValueKey(_obscure),
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Minimum 6 characters';
                }
                return null;
              },
            ),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () {
                    _showForgotPasswordDialog();
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primarySoft,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Login button
            PremiumAnimatedButton(
              width: double.infinity,
              height: 54,
              borderRadius: 30,
              onPressed: () {
                if (_formIsValid && !_loading) {
                  _login();
                }
              },
              color: _formIsValid ? null : Colors.grey.shade400,
              gradient: _formIsValid ? AppColors.primaryGradient : null,
              showGlow: _formIsValid,
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a password reset link.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'your@email.com',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailCtrl.text.trim();
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _showSnack('Password reset email sent!', isError: false);
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _showSnack('Failed to send reset email', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => RegisterScreen(role: widget.role),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              ),
            );
          },
          child: const Text(
            'Register',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // No BoxShadow — that was causing heavy background glow
      ),
    );
  }
}