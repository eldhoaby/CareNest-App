import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aal_app/core/theme/app_theme.dart';
import '../../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  final String role;

  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final dobController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  DateTime? selectedDate;

  @override
  void dispose() {
    nameController.dispose();
    dobController.dispose();
    mobileController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // 📅 Date Picker
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dobController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  // 🔐 Firebase Register
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // Create user in Firebase Auth
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Save extra details in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'name': nameController.text.trim(),
        'dob': dobController.text.trim(),
        'mobile': mobileController.text.trim(),
        'email': emailController.text.trim(),
        'role': widget.role,
        'createdAt': Timestamp.now(),
      });

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully 🎉"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = "Registration failed";

      if (e.code == 'email-already-in-use') {
        message = "Email already registered";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF667EEA).withOpacity(0.06),
              const Color(0xFF764BA2).withOpacity(0.03),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildFormCard(),
                  const SizedBox(height: 40),
                ],
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
        Text(
          "CREATE ACCOUNT",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Join SafeNest for smart assisted living",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: SafeNestTheme.glassCard(Colors.purple),
      child: Column(
        children: [

          _inputField(
            controller: nameController,
            label: "Full Name",
            icon: Icons.person_outline,
            validator: (v) =>
            v == null || v.isEmpty ? "Full name is required" : null,
          ),

          const SizedBox(height: 20),

          // DOB
          TextFormField(
            controller: dobController,
            readOnly: true,
            onTap: _selectDate,
            decoration: InputDecoration(
              labelText: "Date of Birth",
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            validator: (v) =>
            v == null || v.isEmpty ? "Please select date of birth" : null,
          ),

          const SizedBox(height: 20),

          _inputField(
            controller: mobileController,
            label: "Mobile Number",
            icon: Icons.phone_outlined,
            keyboard: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return "Mobile number required";
              if (!RegExp(r'^\d{10}$').hasMatch(v)) {
                return "Enter exactly 10 digits";
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          _inputField(
            controller: emailController,
            label: "Email Address",
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return "Email required";
              final regex =
              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!regex.hasMatch(v)) {
                return "Enter valid email";
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          _passwordField(
            controller: passwordController,
            label: "Password",
            obscure: _obscurePassword,
            toggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),

          const SizedBox(height: 20),

          _passwordField(
            controller: confirmPasswordController,
            label: "Confirm Password",
            obscure: _obscureConfirmPassword,
            toggle: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
            validator: (v) {
              if (v == null || v.isEmpty) return "Confirm your password";
              if (v != passwordController.text) {
                return "Passwords do not match";
              }
              return null;
            },
          ),

          const SizedBox(height: 40),

          PrimaryButton(
            text: _isLoading ? "Creating Account..." : "CREATE ACCOUNT",
            isLoading: _isLoading,
            onPressed: _register,
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon:
          Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      validator: validator ??
              (v) =>
          v == null || v.length < 6 ? "Minimum 6 characters required" : null,
    );
  }
}
