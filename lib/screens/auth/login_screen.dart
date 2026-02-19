import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aal_app/core/theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';
import '../elderly/elderly_dashboard.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../emergency/emergency_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final String role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 🔥 Firebase Login (Corrected Version)
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final input = emailController.text.trim();
      final password = passwordController.text.trim();

      String emailToUse = input;

      // 🔹 If mobile entered → find email from Firestore
      if (!input.contains('@')) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('mobile', isEqualTo: input)
            .get();

        if (snapshot.docs.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'No user found');
        }

        emailToUse = snapshot.docs.first['email'];
      }

      // 🔹 Firebase Auth Sign In
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      // 🔹 Fetch user document safely
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw FirebaseAuthException(
            code: 'user-data-missing',
            message: 'User data not found in database');
      }

      final userData = userDoc.data();
      final userRole = userData?['role'];

      if (userRole == null) {
        throw FirebaseAuthException(
            code: 'role-missing',
            message: 'User role not found');
      }

      setState(() => _isLoading = false);

      // 🔹 Check role matches selected role
      if (userRole.toString().toLowerCase() !=
          widget.role.toLowerCase()) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You are not registered for this role"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 🔹 Navigate by role
      if (userRole.toLowerCase() == 'elderly') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ElderlyDashboard()),
        );
      } else if (userRole.toLowerCase() == 'caregiver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaregiverDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyDashboard()),
        );
      }

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = "Login failed";

      if (e.code == 'user-not-found') {
        message = "No account found";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format";
      } else if (e.code == 'user-data-missing') {
        message = "User record missing in database";
      } else if (e.code == 'role-missing') {
        message = "User role not assigned";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF667EEA).withOpacity(0.08),
              const Color(0xFF764BA2).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildLoginCard(),
                      const SizedBox(height: 32),
                      _buildRegisterLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/images/safenest_logo.png',
          height: 70,
        ),
        const SizedBox(height: 24),
        const Text(
          "Welcome Back 👋",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: SafeNestTheme.glassCard(Colors.blue),
      child: Column(
        children: [

          TextFormField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: 'Email or Mobile Number',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Enter email or mobile number";
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          TextFormField(
            controller: passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return "Minimum 6 characters required";
              }
              return null;
            },
          ),

          const SizedBox(height: 32),

          PrimaryButton(
            text: _isLoading ? "Signing In..." : "Continue",
            isLoading: _isLoading,
            onPressed: _login,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? "),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RegisterScreen(role: widget.role),
              ),
            );
          },
          child: Text(
            "Register Here",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
