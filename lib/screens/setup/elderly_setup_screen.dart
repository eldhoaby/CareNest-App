import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import '../elderly/elderly_dashboard.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ELDERLY SETUP SCREEN — Premium Wizard
// ═══════════════════════════════════════════════════════════════════════════

class ElderlySetupScreen extends StatefulWidget {
  const ElderlySetupScreen({super.key});

  @override
  State<ElderlySetupScreen> createState() => _ElderlySetupScreenState();
}

class _ElderlySetupScreenState extends State<ElderlySetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // ── Step 1: Basic Info ──────────────────────────────────────────────────────
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _gender;
  String? _bloodGroup;
  bool get _step1Valid =>
      _dobCtrl.text.isNotEmpty &&
      _gender != null &&
      _addressCtrl.text.trim().isNotEmpty &&
      _bloodGroup != null;

  // ── Step 2: Health Info ─────────────────────────────────────────────────────
  final _medicalCtrl = TextEditingController();
  String? _mobility;
  bool get _step2Valid => _medicalCtrl.text.isNotEmpty && _mobility != null;

  // ── Step 3: Linking ─────────────────────────────────────────────────────────
  final _linkCtrl = TextEditingController();
  bool _step3Valid = false;

  void _validateStep3() {
    setState(() {
      _step3Valid = _linkCtrl.text.trim().isNotEmpty;
    });
  }

  // ── Step 4: Emergency Info ──────────────────────────────────────────────────
  final _emContactNameCtrl = TextEditingController();
  final _emContactPhoneCtrl = TextEditingController();
  bool get _step4Valid =>
      _emContactNameCtrl.text.trim().length >= 2 &&
      RegExp(r'^\d{10}$').hasMatch(_emContactPhoneCtrl.text.trim());

  // ── Step 5: Permissions ─────────────────────────────────────────────────────
  bool _locPerm = false;
  bool _notifPerm = false;
  bool get _step5Valid => true;

  @override
  void initState() {
    super.initState();
    _linkCtrl.addListener(_validateStep3);
    _emContactNameCtrl.addListener(() => setState(() {}));
    _emContactPhoneCtrl.addListener(() => setState(() {}));
    _medicalCtrl.addListener(() => setState(() {}));
    _addressCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _medicalCtrl.dispose();
    _linkCtrl.dispose();
    _emContactNameCtrl.dispose();
    _emContactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
          'dateOfBirth': _dobCtrl.text,
          'gender': _gender,
          'address': _addressCtrl.text.trim(),
          'bloodGroup': _bloodGroup,
        });
      } else if (_currentStep == 1) {
        await fs.saveSetupStep({
          'medicalConditions': _medicalCtrl.text,
          'mobilityStatus': _mobility
        });
      } else if (_currentStep == 2) {
        final input = _linkCtrl.text.trim();
        await fs.saveSetupStep({'caregiverPhone': input});

        if (RegExp(r'^\d{10}$').hasMatch(input)) {
          final cgUid = await fs.lookupCaregiverByPhone(input);
          if (cgUid != null && fs.currentUid != null) {
            await fs.sendLinkRequest(
                fromUid: fs.currentUid!, toUid: cgUid, fromRole: 'elderly');
          }
        }
      } else if (_currentStep == 3) {
        await fs.saveSetupStep({
          'emergencyContactName': _emContactNameCtrl.text,
          'emergencyContactPhone': _emContactPhoneCtrl.text,
        });
      } else if (_currentStep == 4) {
        await fs.saveSetupStep({
          'locationSharing': _locPerm,
          'notificationsEnabled': _notifPerm,
        });

        await fs.completeSetup();
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ElderlyDashboard()));
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
    }
  }

  bool _isCurrentStepValid() {
    switch (_currentStep) {
      case 0:
        return _step1Valid;
      case 1:
        return _step2Valid;
      case 2:
        return _step3Valid;
      case 3:
        return _step4Valid;
      case 4:
        return _step5Valid;
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
                    'Step ${_currentStep + 1} of 5',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      _stepTitle(),
                      // Skip button for Step 3 (Link Caregiver)
                      if (_currentStep == 2) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _isLoading ? null : () {
                            setState(() => _currentStep = 3);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 8,
            width: MediaQuery.of(context).size.width * ((_currentStep + 1) / 5) - 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle() {
    final titles = [
      'Personal Info',
      'Health Info',
      'Link Caregiver',
      'Emergency',
      'Permissions'
    ];
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
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
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
          'Personal Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Let us know a bit more about you.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        // DOB
        _buildField(
          label: 'Date of Birth',
          hint: 'Select Date',
          icon: Icons.calendar_month_rounded,
          controller: _dobCtrl,
          readOnly: true,
          onTap: _pickDate,
        ),
        const SizedBox(height: 24),
        
        // Gender
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: _inputDeco('Select Gender', Icons.person_rounded),
          dropdownColor: Colors.white,
          items: ['Male', 'Female', 'Other']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 24),

        // Address (Multiline)
        _buildField(
          label: 'Address',
          hint: 'Enter your full address',
          icon: Icons.location_on_outlined,
          controller: _addressCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: 24),

        // Blood Group
        const Text('Blood Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _bloodGroup,
          decoration: _inputDeco('Select Blood Group', Icons.bloodtype_rounded),
          dropdownColor: Colors.white,
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() => _bloodGroup = v),
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
          'Health Overview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'This helps us tune monitoring sensitivity.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        _buildField(
          controller: _medicalCtrl,
          label: 'Existing Medical Conditions',
          hint: 'E.g., Hypertension, Diabetes',
          icon: Icons.local_hospital_rounded,
        ),
        const SizedBox(height: 24),
        
        const Text('Mobility Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _mobility,
          decoration: _inputDeco('Select Status', Icons.accessible_rounded),
          dropdownColor: Colors.white,
          items: ['Independent', 'Uses cane/walker', 'Wheelchair', 'Bedbound']
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _mobility = v),
        ),
      ],
    );
  }

  // ── Step 3 ─────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    final validPhone = RegExp(r'^\d{10}$').hasMatch(_linkCtrl.text.trim());
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Link Caregiver',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Who should be notified in an emergency?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        _buildField(
          controller: _linkCtrl,
          label: 'Caregiver Phone or Invite Code',
          hint: '10-digit phone or code',
          icon: Icons.link_rounded,
          suffixWidget: validPhone
              ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
              : null,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'We will securely send a linking request to this caregiver.',
                  style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 4 ─────────────────────────────────────────────────────────────
  Widget _buildStep4() {
    final phoneValid = RegExp(r'^\d{10}$').hasMatch(_emContactPhoneCtrl.text.trim());
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Contact',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Who should be contacted in an emergency?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        _buildField(
          controller: _emContactNameCtrl,
          label: 'Emergency Contact Name',
          hint: 'Full Name',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 24),
        
        _buildField(
          controller: _emContactPhoneCtrl,
          label: 'Emergency Contact Number',
          hint: '10 digit number',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          suffixWidget: phoneValid
              ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
              : null,
        ),
      ],
    );
  }

  // ── Step 5 ─────────────────────────────────────────────────────────────
  Widget _buildStep5() {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permissions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Required for health background features.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        _buildPermissionTile(
          title: 'Location Access',
          subtitle: 'Needed for geo-fencing and SOS features.',
          icon: Icons.location_on_rounded,
          value: _locPerm,
          onChanged: (v) => setState(() => _locPerm = v),
        ),
        const SizedBox(height: 16),
        _buildPermissionTile(
          title: 'Enable Notifications',
          subtitle: 'Allow critical alerts to wake device.',
          icon: Icons.notifications_active_rounded,
          value: _notifPerm,
          onChanged: (v) => setState(() => _notifPerm = v),
        ),
      ],
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isValid = _isCurrentStepValid();
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: PremiumAnimatedButton(
        onPressed: isValid && !_isLoading ? _submitStep : () {},
        color: isValid ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.3),
        showGlow: isValid,
        height: 56,
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(_currentStep == 4 ? 'Complete Setup' : 'Continue', 
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
                hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w400),
                prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
                suffixIcon: suffixWidget != null
                    ? Padding(padding: const EdgeInsets.only(right: 14), child: suffixWidget)
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w400),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
