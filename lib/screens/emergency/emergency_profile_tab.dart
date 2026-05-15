import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/firebase_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/global_loader.dart';

class EmergencyProfileTab extends StatefulWidget {
  final VoidCallback onLogout;

  const EmergencyProfileTab({
    super.key,
    required this.onLogout,
  });

  @override
  State<EmergencyProfileTab> createState() => _EmergencyProfileTabState();
}

class _EmergencyProfileTabState extends State<EmergencyProfileTab> {
  Map<String, dynamic> _profileData = {};
  bool _isLoaded = false;
  StreamSubscription? _profileSub;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasInitFields = false;

  final _orgNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _alertNotifications = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _startProfileStream();
  }

  void _startProfileStream() {
    _profileSub = FirebaseService.instance.userProfileStream().listen(
      (snapshot) async {
        if (!mounted) return;

        final data = snapshot.data() ?? {};

        final changed = !_isLoaded ||
            data['organizationName'] != _profileData['organizationName'] ||
            data['name'] != _profileData['name'] ||
            data['phone'] != _profileData['phone'];

        if (changed || !_hasInitFields) {
          setState(() {
            _profileData = data;
            _isLoaded = true;
            _alertNotifications = data['notificationsEnabled'] ?? true;
            _soundEnabled = data['alertSoundEnabled'] ?? true;
          });

          if (!_hasInitFields) {
            _orgNameCtrl.text = data['organizationName'] ?? 'Emergency Services';
            _nameCtrl.text = data['name'] ?? '';
            _phoneCtrl.text = data['phone'] ?? '';
            _dobCtrl.text = data['dateOfBirth'] ?? '';
            _addressCtrl.text = data['address'] ?? '';
            _hasInitFields = true;
          }
        }
      },
      onError: (e) => debugPrint("Error loading profile: $e"),
    );
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _orgNameCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_orgNameCtrl.text.trim().isEmpty) {
      _showSnack('Organization Name is required');
      return;
    }
    final phoneRegex = RegExp(r'^\d{10}$');
    if (_phoneCtrl.text.trim().isNotEmpty &&
        !phoneRegex.hasMatch(_phoneCtrl.text.trim())) {
      _showSnack('Phone number must be exactly 10 digits');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseService.instance.updateUserProfile({
        'organizationName': _orgNameCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
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
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const GlobalLoader(isFullScreen: false);
    }

    final email = _profileData['email'] ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 24),
            _buildProfileSummary(name: _orgNameCtrl.text, email: email),
            const SizedBox(height: 16),
            _buildOrganizationDetailsCard(theme),
            const SizedBox(height: 16),
            _buildPersonalDetailsCard(theme),
            const SizedBox(height: 16),
            _buildSettingsCard(theme),
            const SizedBox(height: 24),
            _buildActionButtons(theme, isDark),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Profile',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Material(
          color: _isEditing
              ? AppColors.primary.withValues(alpha: 0.1)
              : theme.cardColor,
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isEditing
                    ? null
                    : AppColors.cardShadow,
              ),
              child: Icon(
                _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                size: 20,
                color: _isEditing
                    ? AppColors.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PROFILE SUMMARY CARD ──────────────────────────────────────

  Widget _buildProfileSummary({required String name, required String email}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.danger,
            const Color(0xFFC0392B), // Deep red for emergency vibe
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33F44336),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Initials avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
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
            name.isNotEmpty ? name : 'Emergency Services',
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
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_hospital_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  'Responder Account',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ORGANIZATION DETAILS CARD ─────────────────────────────────────────────

  Widget _buildOrganizationDetailsCard(ThemeData theme) {
    return _SectionCard(
      title: 'Organization Details',
      icon: Icons.business_rounded,
      children: [
        if (_isEditing) ...[
          _editableRow(
              icon: Icons.badge_rounded,
              label: 'Organization Name',
              controller: _orgNameCtrl,
              theme: theme),
          _divider(),
          _editableRow(
              icon: Icons.location_on_rounded,
              label: 'Address',
              controller: _addressCtrl,
              theme: theme),
        ] else ...[
          _detailRow(Icons.badge_rounded, 'Organization Name', _orgNameCtrl.text, theme),
          _divider(),
          _detailRow(Icons.location_on_rounded, 'Address',
              _addressCtrl.text.isNotEmpty ? _addressCtrl.text : 'Not set', theme),
        ],
      ],
    );
  }

  // ── PERSONAL DETAILS CARD ─────────────────────────────────────────────

  Widget _buildPersonalDetailsCard(ThemeData theme) {
    final parsedDob = _parseDob(_dobCtrl.text);
    final calculatedAge = _calculateAge(parsedDob);
    final ageStr = calculatedAge != null ? '$calculatedAge' : '';

    return _SectionCard(
      title: 'Personal Details',
      icon: Icons.person_outline_rounded,
      children: [
        if (_isEditing) ...[
          _editableRow(
              icon: Icons.person_rounded,
              label: 'Full Name',
              controller: _nameCtrl,
              theme: theme),
          _divider(),
          _editableRow(
              icon: Icons.phone_rounded,
              label: 'Phone Number (10 digits)',
              controller: _phoneCtrl,
              keyboard: TextInputType.phone,
              theme: theme),
          _divider(),
          _editableDateRow(
              icon: Icons.cake_rounded,
              label: 'Date of Birth',
              controller: _dobCtrl,
              onTap: _pickDate,
              theme: theme),
        ] else ...[
          _detailRow(Icons.person_rounded, 'Full Name',
              _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Not set', theme),
          _divider(),
          _detailRow(Icons.phone_rounded, 'Phone Number',
              _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : 'Not set', theme),
          _divider(),
          _detailRow(Icons.cake_rounded, 'Age',
              ageStr.isNotEmpty ? ageStr : 'Not set', theme),
        ],
      ],
    );
  }

  // ── SETTINGS CARD ─────────────────────────────────────────────

  Widget _buildSettingsCard(ThemeData theme) {
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
          theme: theme,
        ),
        _divider(),
        _settingsToggle(
          icon: Icons.notifications_rounded,
          label: 'Alert Notifications',
          subtitle: 'Receive push notifications for emergencies',
          value: _alertNotifications,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _alertNotifications = v);
            FirebaseService.instance.updateUserProfile({'notificationsEnabled': v});
          },
          theme: theme,
        ),
        _divider(),
        _settingsToggle(
          icon: Icons.volume_up_rounded,
          label: 'Alert Sound',
          subtitle: 'Play siren for active emergencies',
          value: _soundEnabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _soundEnabled = v);
            FirebaseService.instance.updateUserProfile({'alertSoundEnabled': v});
          },
          theme: theme,
        ),
      ],
    );
  }

  Widget _settingsToggle({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (value ? AppColors.danger : theme.disabledColor)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 20,
                color:
                    value ? AppColors.danger : theme.disabledColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.danger,
            thumbColor: WidgetStateProperty.all(Colors.white),
          ),
        ],
      ),
    );
  }

  // ── ACTION BUTTONS ────────────────────────────────────────────

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    return Column(
      children: [
        if (_isEditing)
          Material(
            color: AppColors.danger,
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
                              strokeWidth: 2, color: Colors.white))
                    else
                      const Icon(Icons.save_rounded,
                          color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _isSaving ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.mediumImpact();
              _showLogoutConfirmation(theme, isDark);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.15)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(ThemeData theme, bool isDark) {
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.danger, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign Out',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out?\nYou can sign back in at any time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Sign Out',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────

  DateTime? _parseDob(String? dobString) {
    if (dobString == null || dobString.trim().isEmpty) return null;
    try {
      if (dobString.contains('-')) {
        return DateTime.parse(dobString);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate() async {
    final initial = _parseDob(_dobCtrl.text) ?? DateTime(1990, 1, 1);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
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
      if (!mounted) return;
      setState(() {
        _dobCtrl.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _editableDateRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
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
                  readOnly: true,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(labelText: label),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, ThemeData theme) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    required ThemeData theme,
  }) {
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(labelText: label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: AppColors.border);
}

// ── Section Card ───────────────────────────────────────────────

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: theme.brightness == Brightness.light
            ? AppColors.cardShadow
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}
