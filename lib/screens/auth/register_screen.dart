import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';

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

  bool _obscure = true;
  bool _loading = false;

  // Real-time validation state
  bool _nameValid = false;
  bool _phoneValid = false;
  bool _emailValid = true; // optional field
  bool _passwordValid = false;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(_validateFields);
    phoneCtrl.addListener(_validateFields);
    emailCtrl.addListener(_validateFields);
    passwordCtrl.addListener(_validateFields);
  }

  void _validateFields() {
    setState(() {
      _nameValid = nameCtrl.text.trim().length >= 2;
      _phoneValid = RegExp(r'^\d{10}$').hasMatch(phoneCtrl.text.trim());
      final email = emailCtrl.text.trim();
      _emailValid = email.isEmpty || _isValidEmail(email);
      _passwordValid = passwordCtrl.text.length >= 6;
    });
  }

  bool get _formIsValid =>
      _nameValid && _phoneValid && _emailValid && _passwordValid;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(email);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_formIsValid) return;

    setState(() => _loading = true);

    try {
      final email = emailCtrl.text.trim().isNotEmpty
          ? emailCtrl.text.trim()
          : '${phoneCtrl.text.trim()}@smartnest.app';

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created! Please login.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleTitle =
        widget.role[0].toUpperCase() + widget.role.substring(1);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text('Create $roleTitle Account'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${AppConstants.appName} · Signing up as $roleTitle',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Full Name
              _buildField(
                controller: nameCtrl,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline,
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

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
                suffixWidget: _validationIcon(_phoneValid, phoneCtrl.text),
              ),

              const SizedBox(height: 18),

              // Email (Optional)
              _buildField(
                controller: emailCtrl,
                label: 'Email (Optional)',
                hint: 'your@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v != null && v.isNotEmpty && !_isValidEmail(v)) {
                    return 'Invalid email format';
                  }
                  return null;
                },
                suffixWidget: emailCtrl.text.trim().isNotEmpty
                    ? _validationIcon(_emailValid, emailCtrl.text)
                    : null,
              ),

              const SizedBox(height: 18),

              // Password
              _buildField(
                controller: passwordCtrl,
                label: 'Password',
                hint: 'Minimum 6 characters',
                icon: Icons.lock_outlined,
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
                      _validationIcon(_passwordValid, passwordCtrl.text),
                    IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _formIsValid && !_loading ? _register : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: _formIsValid ? 4 : 0,
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
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              if (!_formIsValid && (nameCtrl.text.isNotEmpty ||
                  phoneCtrl.text.isNotEmpty ||
                  passwordCtrl.text.isNotEmpty)) ...[
                const SizedBox(height: 12),
                Text(
                  'Please fill all required fields correctly',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
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
    Widget? suffixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscure : false,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixWidget,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _validationIcon(bool isValid, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        isValid ? Icons.check_circle : Icons.cancel,
        color: isValid ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        size: 20,
      ),
    );
  }
}