import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/notification_service.dart';
import 'register_screen.dart';
import '../elderly/elderly_dashboard.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../emergency/emergency_dashboard.dart';
import '../setup/elderly_setup_screen.dart';
import '../setup/caregiver_setup_screen.dart';
import '../setup/emergency_setup_screen.dart';

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
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  void _validate() {
    final id = identityCtrl.text.trim();
    final isPhone = RegExp(r'^\d{10}$').hasMatch(id);
    final isEmail = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(id);

    setState(() {
      _identityValid = isPhone || isEmail;
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
      final input = identityCtrl.text.trim();
      final password = passwordCtrl.text.trim();

      String emailToUse = input;

      // Phone-based login lookup
      if (!input.contains('@')) {
        final email = await FirebaseService.instance.getEmailByPhone(input);
        if (email == null) {
          throw FirebaseAuthException(code: 'user-not-found');
        }
        emailToUse = email;
      }

      await FirebaseService.instance.loginUser(
        email: emailToUse,
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
      setState(() => _loading = false);
      _showSnack(_friendlyError(e.code), isError: true);
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Login failed. Please try again.', isError: true);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this phone/email';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -90,
            right: -90,
            child: _circle(280, const Color(0xFF6366F1).withValues(alpha: 0.11)),
          ),
          Positioned(
            bottom: -70,
            left: -70,
            child: _circle(240, const Color(0xFF8B5CF6).withValues(alpha: 0.09)),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 28),
                        _buildCard(),
                        const SizedBox(height: 20),
                        _buildRegisterLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final roleIcon = widget.role == 'elderly'
        ? Icons.elderly
        : widget.role == 'caregiver'
            ? Icons.favorite
            : Icons.local_hospital;

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(roleIcon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        const Text(
          AppConstants.appName,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          '${widget.role[0].toUpperCase()}${widget.role.substring(1)} Login',
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Phone / Email
            TextFormField(
              controller: identityCtrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Phone or Email',
                hintText: 'Enter 10-digit phone or email',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                suffixIcon: identityCtrl.text.isNotEmpty
                    ? Icon(
                        _identityValid
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _identityValid
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        size: 20,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter phone or email';
                }
                final trimmed = v.trim();
                final isPhone = RegExp(r'^\d{10}$').hasMatch(trimmed);
                final isEmail =
                    RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(trimmed);
                if (!isPhone && !isEmail) {
                  return 'Enter valid 10-digit phone or email';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // Password
            TextFormField(
              controller: passwordCtrl,
              obscureText: _obscure,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Minimum 6 characters',
                prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (passwordCtrl.text.isNotEmpty)
                      Icon(
                        _passwordValid
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _passwordValid
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Minimum 6 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _formIsValid && !_loading ? _login : null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ",
            style: TextStyle(color: Colors.grey[600])),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RegisterScreen(role: widget.role),
              ),
            );
          },
          child: const Text(
            'Register',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}