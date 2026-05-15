import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_animated_button.dart';
import '../caregiver/caregiver_dashboard.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CAREGIVER SETUP SCREEN — Premium Wizard
// ═══════════════════════════════════════════════════════════════════════════

class CaregiverSetupScreen extends StatefulWidget {
  const CaregiverSetupScreen({super.key});

  @override
  State<CaregiverSetupScreen> createState() => _CaregiverSetupScreenState();
}

class _CaregiverSetupScreenState extends State<CaregiverSetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // ── Step 1: Link Elderly ──────────────────────────────────────────────────
  final _linkCtrl = TextEditingController();
  bool _step1Valid = false;

  void _validateStep1() {
    setState(() {
      _step1Valid = _linkCtrl.text.trim().isNotEmpty;
    });
  }

  // ── Step 2: Relationship ──────────────────────────────────────────────────
  String? _relation;
  bool get _step2Valid => _relation != null;

  // ── Step 3: Notifications ─────────────────────────────────────────────────
  bool _notifPerm = true;
  bool get _step3Valid => true;

  @override
  void initState() {
    super.initState();
    _linkCtrl.addListener(_validateStep1);
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitStep() async {
    setState(() => _isLoading = true);
    final fs = FirebaseService.instance;

    try {
      if (_currentStep == 0) {
        final input = _linkCtrl.text.trim();

        if (input.length == 6 && !RegExp(r'^\d+$').hasMatch(input)) {
          final success = await fs.tryAutoLinkWithCode(input.toUpperCase(), 'caregiver');
          if (!success) {
            _showError('Invalid or expired invite code');
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        } else if (RegExp(r'^\d{10}$').hasMatch(input)) {
          final elderlyUid = await fs.lookupElderlyByPhone(input);
          if (elderlyUid != null && fs.currentUid != null) {
            await fs.sendLinkRequest(fromUid: fs.currentUid!, toUid: elderlyUid, fromRole: 'caregiver');
          } else {
            _showError('No elderly user found with this phone number');
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        } else {
          _showError('Please enter a valid phone number or code');
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      } else if (_currentStep == 1) {
        await fs.saveSetupStep({'relationship': _relation});
      } else if (_currentStep == 2) {
        await fs.saveSetupStep({'notificationsEnabled': _notifPerm});

        await fs.completeSetup();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CaregiverDashboard()));
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
      case 2:
        return _step3Valid;
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
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
                    'Step ${_currentStep + 1} of 3',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      _stepTitle(),
                      if (_currentStep == 0) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _isLoading ? null : () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CaregiverDashboard()));
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
            width: MediaQuery.of(context).size.width * ((_currentStep + 1) / 3) - 48,
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
    final titles = ['Link Elderly', 'Relationship', 'Notifications'];
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
          'Link to Elderly',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect with the person you are caring for.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        _buildField(
          controller: _linkCtrl,
          label: 'Elderly Phone or Invite Code',
          hint: 'Code from Elderly profile',
          icon: Icons.link_rounded,
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
                  'Enter their 10-digit phone number to send a request, or their 6-character invite code to link instantly.',
                  style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
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
          'Relationship',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'What is your relation to the elderly user?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        const Text('Relation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _relation,
          decoration: _inputDeco('Select Relationship', Icons.family_restroom_rounded),
          dropdownColor: Colors.white,
          items: ['Son', 'Daughter', 'Spouse', 'Professional Nurse', 'Other']
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) => setState(() => _relation = v),
        ),
      ],
    );
  }

  // ── Step 3 ─────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Critical alerts will bypass silent mode when possible.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        
        _buildPermissionTile(
          title: 'Receive All Alerts',
          subtitle: 'Includes falls, inactivity warnings, and SOS triggers.',
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
            : Text(_currentStep == 2 ? 'Complete Setup' : 'Continue', 
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
              keyboardType: keyboardType,
              readOnly: readOnly,
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
