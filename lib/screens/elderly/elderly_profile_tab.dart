import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/firebase_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/premium/glass_card.dart';
import 'widgets/linked_caregivers_section.dart';
import '../../widgets/global_loader.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ELDERLY PROFILE TAB — Premium, Fully Editable & Adaptive Profile
// ═══════════════════════════════════════════════════════════════════════════

class ElderlyProfileTab extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const ElderlyProfileTab({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<ElderlyProfileTab> createState() => _ElderlyProfileTabState();
}

class _ElderlyProfileTabState extends State<ElderlyProfileTab> {
  // ── Profile data (cached from stream) ───────────────────────
  Map<String, dynamic> _profileData = {};
  bool _isLoaded = false;
  StreamSubscription? _profileSub;

  // ── Edit mode ───────────────────────────────────────────────
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasInitFields = false;

  // ── Invite code ─────────────────────────────────────────────
  String? _inviteCode;
  bool _generatingCode = false;

  // ── Settings toggles ───────────────────────────────────────
  bool _alertNotifications = true;
  bool _soundEnabled = true;

  // ── Editable fields ────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String? _bloodGroup;

  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();

  // ── Medical info controllers (Bug #2 fix) ──────────────────
  final _medicalConditionsCtrl = TextEditingController();
  final _mobilityStatusCtrl = TextEditingController();

  final List<String> _bloodGroupOptions = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    _startProfileStream();
  }

  void _startProfileStream() {
    _profileSub = FirebaseService.instance.userProfileStream().listen(
      (snapshot) {
        if (!mounted) return;

        final data = snapshot.data() ?? {};

        final changed = !_isLoaded ||
            data['name'] != _profileData['name'] ||
            data['inviteCode'] != _profileData['inviteCode'];

        if (changed || !_hasInitFields) {
          setState(() {
            _profileData = data;
            _isLoaded = true;
            if (data['inviteCode'] != null && _inviteCode == null) {
              _inviteCode = data['inviteCode'];
            }
            _alertNotifications = data['notificationsEnabled'] ?? true;
            _soundEnabled = data['alertSoundEnabled'] ?? true;
          });

          if (!_hasInitFields) {
            _nameCtrl.text = data['name'] ?? widget.userName;
            _phoneCtrl.text = data['phone'] ?? '';
            _addressCtrl.text = data['address'] ?? '';
            _dobCtrl.text = data['dateOfBirth'] ?? '';
            
            final bg = data['bloodGroup'];
            _bloodGroup = _bloodGroupOptions.contains(bg) ? bg : null;

            _emergNameCtrl.text = data['emergencyContactName'] ?? '';
            _emergPhoneCtrl.text = data['emergencyContactPhone'] ?? '';

            // Medical info controllers (Bug #2 fix)
            _medicalConditionsCtrl.text = data['medicalConditions'] ?? '';
            _mobilityStatusCtrl.text = data['mobilityStatus'] ?? '';
            _hasInitFields = true;
          }
        }
      },
      onError: (e) {
        debugPrint("Error loading profile: $e");
      }
    );
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    _emergNameCtrl.dispose();
    _emergPhoneCtrl.dispose();
    _medicalConditionsCtrl.dispose();
    _mobilityStatusCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────

  DateTime? _parseDob(String? dobString) {
    if (dobString == null || dobString.trim().isEmpty) return null;
    try {
      if (dobString.contains('-')) {
        return DateTime.parse(dobString);
      }
      return DateFormat('dd MMM yyyy').parse(dobString);
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy').parse(dobString);
      } catch (_) {
        return null;
      }
    }
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate() async {
    final initial = _parseDob(_dobCtrl.text) ?? DateTime(1950, 1, 1);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _dobCtrl.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveProfile() async {
    // Validation
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Name is required');
      return;
    }

    final phoneRegex = RegExp(r'^\d{10}$');
    if (_phoneCtrl.text.trim().isNotEmpty && !phoneRegex.hasMatch(_phoneCtrl.text.trim())) {
      _showSnack('Phone number must be exactly 10 digits');
      return;
    }

    if (_emergPhoneCtrl.text.trim().isNotEmpty && !phoneRegex.hasMatch(_emergPhoneCtrl.text.trim())) {
      _showSnack('Emergency contact phone must be exactly 10 digits');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseService.instance.updateUserProfile({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text.trim(),
        'bloodGroup': _bloodGroup,
        'emergencyContactName': _emergNameCtrl.text.trim(),
        'emergencyContactPhone': _emergPhoneCtrl.text.trim(),
        // Medical info (Bug #2 fix)
        'medicalConditions': _medicalConditionsCtrl.text.trim(),
        'mobilityStatus': _mobilityStatusCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      _showSnack('Profile updated successfully', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Failed to save profile');
    }
  }

  Future<void> _generateInviteCode() async {
    setState(() => _generatingCode = true);
    try {
      final code = await FirebaseService.instance.generateInviteCode();
      setState(() {
        _inviteCode = code;
        _generatingCode = false;
      });
    } catch (e) {
      setState(() => _generatingCode = false);
      _showSnack('Failed to generate code');
    }
  }

  void _copyInviteCode() {
    if (_inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    HapticFeedback.mediumImpact();
    _showSnack('Invite code copied!', isSuccess: true);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const GlobalLoader(isFullScreen: false);
    }

    final email = _profileData['email'] ?? widget.userEmail;
    final gender = _profileData['gender'] ?? '';

    // Calculate age dynamically
    final parsedDob = _parseDob(_dobCtrl.text);
    final calculatedAge = _calculateAge(parsedDob);
    final ageStr = calculatedAge != null ? '$calculatedAge' : '-';

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            _buildHeader(),
            const SizedBox(height: 24),

            // 2. Profile Summary Card
            _buildProfileSummary(name: _nameCtrl.text, email: email),
            const SizedBox(height: 16),

            // 3. Personal Details Card
            _buildPersonalDetailsCard(
              age: ageStr,
              gender: gender,
            ),
            const SizedBox(height: 16),

            // 4. Medical Information Card — always visible (Bug #2 fix)
            _buildMedicalCard(),
            const SizedBox(height: 16),

            // 5. Emergency Contact Card
            _buildCaregiverCard(),
            const SizedBox(height: 16),

            LinkedCaregiversSection(elderlyUid: FirebaseService.instance.currentUid ?? ''),
            const SizedBox(height: 16),

            // 6. Invite Code Card
            _buildInviteCodeCard(),
            const SizedBox(height: 16),

            // 7. Settings Card
            _buildSettingsCard(),
            const SizedBox(height: 24),

            // 8. Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 1. HEADER
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Profile',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 2. PROFILE SUMMARY CARD
  // ════════════════════════════════════════════════════════════════

   Widget _buildProfileSummary({
    required String name,
    required String email,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: AppColors.dashboardGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Letter avatar — no image upload
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name.isNotEmpty ? name : 'User',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              // Bug #5 fix: Wrap instead of Row to prevent overflow
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _profileBadge('Elderly User', Icons.person_rounded),
                  _profileBadge('Monitoring Active', Icons.circle,
                      dotColor: AppColors.success),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Material(
            color: Colors.white.withValues(alpha: _isEditing ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isEditing = !_isEditing);
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileBadge(String label, IconData icon, {Color? dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 3. PERSONAL DETAILS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildPersonalDetailsCard({
    required String age,
    required String gender,
  }) {
    return _SectionCard(
      title: 'Personal Details',
      icon: Icons.person_outline_rounded,
      children: [
        if (_isEditing) ...[
          _editableRow(
            icon: Icons.badge_rounded,
            label: 'Full Name',
            controller: _nameCtrl,
          ),
          _divider(),
          _editableRow(
            icon: Icons.phone_rounded,
            label: 'Phone (10 digits)',
            controller: _phoneCtrl,
            keyboard: TextInputType.phone,
          ),
          _divider(),
          _editableRow(
            icon: Icons.location_on_rounded,
            label: 'Address',
            controller: _addressCtrl,
          ),
          _divider(),
          _editableDateRow(
            icon: Icons.cake_rounded,
            label: 'Date of Birth',
            controller: _dobCtrl,
            onTap: _pickDate,
          ),
          _divider(),
          _editableDropdownRow(
            icon: Icons.bloodtype_rounded,
            label: 'Blood Group',
            value: _bloodGroup,
            options: _bloodGroupOptions,
            onChanged: (val) => setState(() => _bloodGroup = val),
          ),
        ] else ...[
          _detailRow(Icons.badge_rounded, 'Full Name', _nameCtrl.text),
          _divider(),
          _detailRow(Icons.cake_rounded, 'Age', age.isNotEmpty ? age : '-'),
          _divider(),
          _detailRow(Icons.bloodtype_rounded, 'Blood Group', _bloodGroup ?? '-'),
          _divider(),
          _detailRow(
            gender.toLowerCase() == 'female'
                ? Icons.female_rounded
                : Icons.male_rounded,
            'Gender',
            gender.isNotEmpty ? gender : '-',
          ),
          _divider(),
          _detailRow(Icons.phone_rounded, 'Phone',
              _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : '-'),
          _divider(),
          _detailRow(Icons.location_on_rounded, 'Address',
              _addressCtrl.text.isNotEmpty ? _addressCtrl.text : '-'),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 4. MEDICAL INFORMATION CARD
  // ════════════════════════════════════════════════════════════════

  /// Bug #2 fix: Medical card now supports edit mode with controllers
  Widget _buildMedicalCard() {
    final conditions = _medicalConditionsCtrl.text;
    final mobility = _mobilityStatusCtrl.text;

    return _SectionCard(
      title: 'Medical Information',
      icon: Icons.medical_information_rounded,
      accentColor: AppColors.danger,
      children: [
        if (_isEditing) ...[
          _editableRow(
            icon: Icons.local_hospital_rounded,
            label: 'Medical Conditions',
            controller: _medicalConditionsCtrl,
          ),
          _divider(),
          _editableRow(
            icon: Icons.accessible_rounded,
            label: 'Mobility Status',
            controller: _mobilityStatusCtrl,
          ),
        ] else ...[
          _detailRow(
            Icons.local_hospital_rounded,
            'Conditions',
            conditions.isNotEmpty ? conditions : 'Not specified',
          ),
          _divider(),
          _detailRow(
            Icons.accessible_rounded,
            'Mobility',
            mobility.isNotEmpty ? mobility : 'Not specified',
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 5. CAREGIVER DETAILS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildCaregiverCard() {
    final name = _emergNameCtrl.text;
    final phone = _emergPhoneCtrl.text;
    final hasData = name.isNotEmpty || phone.isNotEmpty;

    return _SectionCard(
      title: 'Emergency Contact',
      icon: Icons.people_rounded,
      accentColor: AppColors.secondary,
      children: [
        if (_isEditing) ...[
          _editableRow(
            icon: Icons.person_rounded,
            label: 'Contact Name',
            controller: _emergNameCtrl,
          ),
          _divider(),
          _editableRow(
            icon: Icons.phone_rounded,
            label: 'Contact Phone (10 digits)',
            controller: _emergPhoneCtrl,
            keyboard: TextInputType.phone,
          ),
        ] else ...[
          _detailRow(Icons.person_rounded, 'Contact Name',
              hasData ? name : 'Not set'),
          _divider(),
          _detailRow(Icons.phone_rounded, 'Contact Phone',
              phone.isNotEmpty ? phone : 'Not set'),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // INVITE CODE CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildInviteCodeCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF3B2711) : const Color(0xFFFFF7ED);
    final borderColor = isDark ? const Color(0xFF92400E) : AppColors.warning.withValues(alpha: 0.25);
    final titleColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
    final subtitleColor = isDark ? AppColors.warning : const Color(0xFFB45309);
    final codeBlockBg = isDark ? const Color(0xFF1F1206) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.vpn_key_rounded,
                    color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caregiver Invite Code',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share with your caregiver to link accounts',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_inviteCode != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: codeBlockBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  _inviteCode!,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: titleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _outlineButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: _copyInviteCode,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _outlineButton(
                    icon: Icons.refresh_rounded,
                    label: 'Regenerate',
                    onTap: _generatingCode ? null : _generateInviteCode,
                    color: theme.textTheme.bodyMedium?.color ?? AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ] else ...[
            Material(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _generatingCode ? null : _generateInviteCode,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_generatingCode)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.vpn_key_rounded,
                            color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _generatingCode ? 'Generating...' : 'Generate Invite Code',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 6. SETTINGS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildSettingsCard() {
    // Read dark mode state from ThemeProvider (global)
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkEnabled = themeProvider.isDarkMode;

    return _SectionCard(
      title: 'Settings',
      icon: Icons.settings_rounded,
      accentColor: AppColors.textSecondary,
      children: [
        _settingsToggle(
          icon: Icons.dark_mode_rounded,
          label: 'Dark Mode',
          subtitle: 'Switch between light and dark theme',
          value: isDarkEnabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            context.read<ThemeProvider>().toggleTheme(v);
          },
        ),
        _divider(),
        _settingsToggle(
          icon: Icons.notifications_rounded,
          label: 'Alert Notifications',
          subtitle: 'Receive push notifications',
          value: _alertNotifications,
          onChanged: (v) async {
            HapticFeedback.selectionClick();
            setState(() {
              _alertNotifications = v;
              if (!v) _soundEnabled = false; // Turn off sound if notifs are off
            });
            await FirebaseService.instance.updateUserProfile({'notificationsEnabled': v, 'alertSoundEnabled': _soundEnabled});
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notificationsEnabled', v);
            await prefs.setBool('soundEnabled', _soundEnabled);
          },
        ),
        _divider(),
        _settingsToggle(
          icon: Icons.volume_up_rounded,
          label: 'Alert Sound',
          subtitle: 'Play sound for alerts',
          value: _soundEnabled && _alertNotifications,
          onChanged: _alertNotifications ? (v) async {
            HapticFeedback.selectionClick();
            setState(() => _soundEnabled = v);
            await FirebaseService.instance.updateUserProfile({'alertSoundEnabled': v});
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('soundEnabled', v);
          } : null, // Disable toggle if notifications are off
        ),
      ],
    );
  }

  Widget _settingsToggle({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged, // nullable → disables switch when null
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDisabled = onChanged == null;
    final effectiveColor = isDisabled
        ? theme.disabledColor
        : (value ? AppColors.primary : theme.disabledColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: effectiveColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isDisabled ? false : value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
              thumbColor: WidgetStateProperty.all(Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 7. ACTION BUTTONS
  // ════════════════════════════════════════════════════════════════

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_isEditing)
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isSaving ? null : _saveProfile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.save_rounded,
                          color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _isSaving ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Material(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isEditing = true);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        Material(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.mediumImpact();
              _showLogoutConfirmation();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded,
                      color: AppColors.danger, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.danger, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign Out',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out?\nYou can sign back in anytime.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onLogout();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════

  Widget _detailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : '-',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboard,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableDateRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: AbsorbPointer(
                child: TextField(
                  controller: controller,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableDropdownRow({
    required IconData icon,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: value,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChanged,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: Theme.of(context).dividerTheme.color);
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? AppColors.primary;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}