import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import '../../widgets/global_loader.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  // Real-time validation state
  bool _nameValid = false;
  bool _phoneValid = false;
  bool _emailValid = false; // required field
  bool _passwordValid = false;
  bool _confirmPasswordValid = false;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(_validateFields);
    phoneCtrl.addListener(_validateFields);
    emailCtrl.addListener(_validateFields);
    passwordCtrl.addListener(_validateFields);
    confirmPasswordCtrl.addListener(_validateFields);
  }

  void _validateFields() {
    setState(() {
      _nameValid = nameCtrl.text.trim().length >= 2;
      _phoneValid = RegExp(r'^\d{10}$').hasMatch(phoneCtrl.text.trim());
      final email = emailCtrl.text.trim();
      _emailValid = email.isNotEmpty && _isValidEmail(email);
      _passwordValid = passwordCtrl.text.length >= 6;
      _confirmPasswordValid = confirmPasswordCtrl.text.isNotEmpty &&
          confirmPasswordCtrl.text == passwordCtrl.text;
    });
  }

  bool get _formIsValid =>
      _nameValid && _phoneValid && _emailValid && _passwordValid && _confirmPasswordValid;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(email);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_formIsValid) return;

    setState(() => _loading = true);

    try {
      final email = emailCtrl.text.trim();

      await FirebaseService.instance.registerUser(
        email: email,
        password: passwordCtrl.text.trim(),
        profileData: {
          'name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'email': email,
          'role': widget.role,
          'profileComplete': false,
        },
      );

      // Sign out so user can login fresh
      await FirebaseService.instance.logout();

      if (!mounted) return;

      _showSnack('Account created! Please sign in.', isError: false);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showSnack('$e', isError: true);
    }
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
    final roleTitle =
        widget.role[0].toUpperCase() + widget.role.substring(1);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
        title: Text(
          'Create $roleTitle Account',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primarySoft.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: AppColors.primarySoft, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${AppConstants.appName} · Registering as $roleTitle',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primarySoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Full Name
                    _buildField(
                      controller: nameCtrl,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) {
                        if (v == null || v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                      suffixWidget: nameCtrl.text.isNotEmpty ? _validationIcon(_nameValid) : null,
                    ),

                    const SizedBox(height: 20),

                    // Phone Number
                    _buildField(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      hint: '10-digit mobile number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                          return 'Must be exactly 10 digits';
                        }
                        return null;
                      },
                      suffixWidget: phoneCtrl.text.isNotEmpty ? _validationIcon(_phoneValid) : null,
                    ),

                    const SizedBox(height: 20),

                    // Email (Required)
                    _buildField(
                      controller: emailCtrl,
                      label: 'Email',
                      hint: 'your@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!_isValidEmail(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                      suffixWidget: emailCtrl.text.trim().isNotEmpty
                          ? _validationIcon(_emailValid)
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // Password
                    _buildField(
                      controller: passwordCtrl,
                      label: 'Password',
                      hint: 'Minimum 6 characters',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      suffixWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (passwordCtrl.text.isNotEmpty)
                            _validationIcon(_passwordValid),
                          IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                key: ValueKey(_obscure),
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confirm Password
                    _buildField(
                      controller: confirmPasswordCtrl,
                      label: 'Confirm Password',
                      hint: 'Re-enter your password',
                      icon: Icons.lock_rounded,
                      isConfirmPassword: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      suffixWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (confirmPasswordCtrl.text.isNotEmpty)
                            _validationIcon(_confirmPasswordValid),
                          IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                key: ValueKey(_obscureConfirm),
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Register button — pill-shaped matching login
              PremiumAnimatedButton(
                width: double.infinity,
                height: 54,
                borderRadius: 30,
                onPressed: () {
                  if (_formIsValid && !_loading) {
                    _register();
                  }
                },
                color: _formIsValid ? null : Colors.grey.shade400,
                gradient: _formIsValid ? AppColors.primaryGradient : null,
                showGlow: _formIsValid,
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),

              if (!_formIsValid && (nameCtrl.text.isNotEmpty ||
                  phoneCtrl.text.isNotEmpty ||
                  passwordCtrl.text.isNotEmpty)) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Please fill all required fields correctly',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.danger.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    ),
    if (_loading)
      const GlobalLoader(isFullScreen: true),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    bool isPassword = false,
    bool isConfirmPassword = false,
    Widget? suffixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscure : (isConfirmPassword ? _obscureConfirm : false),
          keyboardType: keyboardType,
          inputFormatters: formatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixWidget,
          ),
        ),
      ],
    );
  }

  Widget _validationIcon(bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(
        isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: isValid ? AppColors.success : AppColors.danger,
        size: 20,
      ),
    );
  }
}