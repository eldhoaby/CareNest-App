import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import '../emergency/emergency_dashboard.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EMERGENCY SETUP SCREEN — Premium Wizard
// ═══════════════════════════════════════════════════════════════════════════

class EmergencySetupScreen extends StatefulWidget {
  const EmergencySetupScreen({super.key});

  @override
  State<EmergencySetupScreen> createState() => _EmergencySetupScreenState();
}

class _EmergencySetupScreenState extends State<EmergencySetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // ── Step 1: Organization Info ───────────────────────────────────────────────
  final _orgCtrl = TextEditingController();
  final _orgAddressCtrl = TextEditingController();
  bool get _step1Valid =>
      _orgCtrl.text.trim().length >= 2 &&
      _orgAddressCtrl.text.trim().length >= 5;

  // ── Step 2: Personal Info ───────────────────────────────────────────────────
  final _dobCtrl = TextEditingController();
  final _personalAddressCtrl = TextEditingController();

  bool get _step2Valid =>
      _dobCtrl.text.trim().isNotEmpty &&
      _personalAddressCtrl.text.trim().length >= 5;

  @override
  void initState() {
    super.initState();
    _orgCtrl.addListener(() => setState(() {}));
    _orgAddressCtrl.addListener(() => setState(() {}));
    _dobCtrl.addListener(() => setState(() {}));
    _personalAddressCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _orgCtrl.dispose();
    _orgAddressCtrl.dispose();
    _dobCtrl.dispose();
    _personalAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.danger),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _dobCtrl.text =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submitStep() async {
    setState(() => _isLoading = true);
    final fs = FirebaseService.instance;

    try {
      if (_currentStep == 0) {
        await fs.saveSetupStep({
          'organizationName': _orgCtrl.text.trim(),
          'organizationAddress': _orgAddressCtrl.text.trim(),
        });
      } else if (_currentStep == 1) {
        await fs.saveSetupStep({
          'dateOfBirth': _dobCtrl.text.trim(),
          'address': _personalAddressCtrl.text.trim(),
        });

        await fs.completeSetup();
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const EmergencyDashboard()));
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('An error occurred. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  bool _isCurrentStepValid() {
    switch (_currentStep) {
      case 0:
        return _step1Valid;
      case 1:
        return _step2Valid;
      default:
        return false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Setup Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),

            // Step Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of 2',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                      fontSize: 14,
                    ),
                  ),
                  _stepTitle(),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ),

            // Bottom Nav
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 8,
            width: MediaQuery.of(context).size.width * ((_currentStep + 1) / 2) - 48,
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle() {
    final titles = ['Organization', 'Personal Info'];
    return Text(
      titles[_currentStep],
      style: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      default:
        return const SizedBox();
    }
  }

  // ── Step 1 ─────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organization Info',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Details regarding your response team or hospital.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        _buildField(
          controller: _orgCtrl,
          label: 'Organization Name',
          hint: 'Hospital or Clinic Name',
          icon: Icons.local_hospital_rounded,
        ),
        const SizedBox(height: 24),
        _buildField(
          controller: _orgAddressCtrl,
          label: 'Organization Address',
          hint: 'Enter organization address',
          icon: Icons.location_on_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  // ── Step 2 ─────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Info',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Provide your details for the emergency profile.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        _buildField(
          controller: _dobCtrl,
          label: 'Date of Birth',
          hint: 'Select Date',
          icon: Icons.calendar_month_rounded,
          readOnly: true,
          onTap: _pickDate,
        ),
        const SizedBox(height: 24),
        _buildField(
          controller: _personalAddressCtrl,
          label: 'Address',
          hint: 'Enter your personal address',
          icon: Icons.location_on_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isValid = _isCurrentStepValid();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: PremiumAnimatedButton(
        onPressed: isValid && !_isLoading ? _submitStep : () {},
        color: isValid
            ? AppColors.danger
            : AppColors.textMuted.withValues(alpha: 0.3),
        showGlow: isValid,
        height: 56,
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(_currentStep == 1 ? 'Complete Setup' : 'Continue', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isValid ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  // ── Shared Field Builder ───────────────────────────────────────────────
  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    TextEditingController? controller,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixWidget,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            absorbing: onTap != null,
            child: TextFormField(
              controller: controller,
              keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
              readOnly: readOnly,
              maxLines: maxLines,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontWeight: FontWeight.w400),
                prefixIcon: Icon(icon, color: AppColors.danger, size: 20),
                suffixIcon: suffixWidget != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: suffixWidget)
                    : null,
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.8),
                      width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.8),
                      width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.danger, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

}
