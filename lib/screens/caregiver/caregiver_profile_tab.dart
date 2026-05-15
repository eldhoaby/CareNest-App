import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/firebase_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/global_loader.dart';

class CaregiverProfileTab extends StatefulWidget {
  final VoidCallback onLogout;

  const CaregiverProfileTab({
    super.key,
    required this.onLogout,
  });

  @override
  State<CaregiverProfileTab> createState() => _CaregiverProfileTabState();
}

class _CaregiverProfileTabState extends State<CaregiverProfileTab> {
  Map<String, dynamic> _profileData = {};
  bool _isLoaded = false;
  StreamSubscription? _profileSub;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasInitFields = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Linking logic
  final _codeCtrl = TextEditingController();
  bool _isLinking = false;
  String? _linkedElderlyName;

  // Full elderly profile for the Assigned Patient card
  Map<String, dynamic> _elderlyData = {};

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
            data['name'] != _profileData['name'] ||
            data['linkedElderlyUid'] != _profileData['linkedElderlyUid'];

        if (changed || !_hasInitFields) {
          setState(() {
            _profileData = data;
            _isLoaded = true;
            _alertNotifications = data['notificationsEnabled'] ?? true;
            _soundEnabled = data['alertSoundEnabled'] ?? true;
          });

          if (!_hasInitFields) {
            _nameCtrl.text = data['name'] ?? 'Caregiver';
            _phoneCtrl.text = data['phone'] ?? '';
            _hasInitFields = true;
          }

          // Fetch full elderly profile whenever linkedElderlyUid changes
          if (data['linkedElderlyUid'] != null) {
            final elderlyDoc = await FirebaseService.instance
                .userProfileStreamById(data['linkedElderlyUid'])
                .first;
            final eData = elderlyDoc.data() ?? {};
            if (mounted) {
              setState(() {
                _linkedElderlyName = eData['name'] as String?;
                _elderlyData = eData;
              });
            }
          } else if (data['linkedElderlyUid'] == null) {
            setState(() {
              _linkedElderlyName = null;
              _elderlyData = {};
            });
          }
        }
      },
      onError: (e) => debugPrint("Error loading profile: $e"),
    );
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Name is required');
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
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
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

  Future<void> _linkElderly() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnack('Invalid invite code format');
      return;
    }
    setState(() => _isLinking = true);
    try {
      final success =
          await FirebaseService.instance.tryAutoLinkWithCode(code, 'caregiver');
      if (!mounted) return;
      if (success) {
        _showSnack('Elderly user linked successfully!', isSuccess: true);
        _codeCtrl.clear();
      } else {
        _showSnack('Invalid or expired code.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error linking account');
    } finally {
      if (mounted) setState(() => _isLinking = false);
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
            _buildProfileSummary(name: _nameCtrl.text, email: email),
            const SizedBox(height: 16),
            _buildLinkCard(theme),
            const SizedBox(height: 16),
            _buildPersonalDetailsCard(theme),
            const SizedBox(height: 16),
            // Assigned Patient card — visible only when linked
            if (_profileData['linkedElderlyUid'] != null) ...[
              _buildAssignedElderlyCard(theme),
              const SizedBox(height: 16),
            ],
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
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return Container(
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
          // Initials avatar with dashboardGradient halo
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
            name.isNotEmpty ? name : 'Caregiver',
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
          // Badge — outlined chip style
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
                Icon(Icons.security_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  'Caregiver Account',
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

  // ── LINK CARD ─────────────────────────────────────────────────

  Widget _buildLinkCard(ThemeData theme) {
    return _SectionCard(
      title: 'Linked Patient',
      icon: Icons.link_rounded,
      accentColor: AppColors.secondary,
      children: [
        if (_profileData['linkedElderlyUid'] != null)
          _detailRow(Icons.elderly_rounded, 'Monitoring',
              _linkedElderlyName ?? 'Loading...', theme)
        else ...[
          Text(
            'Enter an invite code to link an elderly user to monitor.',
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code (e.g. A1B2C3)',
                    counterText: '',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLinking ? null : _linkElderly,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                ),
                child: _isLinking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Link',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── PERSONAL DETAILS CARD ─────────────────────────────────────

  Widget _buildPersonalDetailsCard(ThemeData theme) {
    return _SectionCard(
      title: 'Personal Details',
      icon: Icons.person_outline_rounded,
      children: [
        if (_isEditing) ...[
          _editableRow(
              icon: Icons.badge_rounded,
              label: 'Full Name',
              controller: _nameCtrl,
              theme: theme),
          _divider(),
          _editableRow(
              icon: Icons.phone_rounded,
              label: 'Phone (10 digits)',
              controller: _phoneCtrl,
              keyboard: TextInputType.phone,
              theme: theme),
        ] else ...[
          _detailRow(Icons.badge_rounded, 'Full Name', _nameCtrl.text, theme),
          _divider(),
          _detailRow(Icons.phone_rounded, 'Phone',
              _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : 'Not set', theme),
        ],
      ],
    );
  }

  // ── ASSIGNED ELDERLY CARD ──────────────────────────────────────

  /// Calculate age from a DOB string (supports ISO date and 'dd MMM yyyy')
  int? _calcAge(String? dob) {
    if (dob == null || dob.trim().isEmpty) return null;
    try {
      DateTime? parsed;
      if (dob.contains('-')) {
        parsed = DateTime.tryParse(dob);
      } else {
        // Try 'dd MMM yyyy' manually
        final parts = dob.split(' ');
        if (parts.length == 3) {
          const months = {
            'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
            'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
            'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
          };
          final m = months[parts[1]];
          if (m != null) {
            parsed = DateTime(int.parse(parts[2]), m, int.parse(parts[0]));
          }
        }
      }
      if (parsed == null) {
        return null;
      }
      final today = DateTime.now();
      int age = today.year - parsed.year;
      if (today.month < parsed.month ||
          (today.month == parsed.month && today.day < parsed.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  Future<void> _callElderly(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open dialer')),
          );
        }
      }
    } catch (e) {
      debugPrint('Call elderly error: $e');
    }
  }

  Widget _buildAssignedElderlyCard(ThemeData theme) {
    final name        = _elderlyData['name']       as String? ?? '—';
    final dob         = _elderlyData['dateOfBirth'] as String?;
    final age         = _calcAge(dob);
    final ageStr      = age != null ? '$age yrs' : '—';
    final blood       = _elderlyData['bloodGroup']        as String? ?? '—';
    final conditions  = _elderlyData['medicalConditions'] as String? ?? '—';
    final mobility    = _elderlyData['mobilityStatus']    as String? ?? '—';
    final phone       = _elderlyData['phone']             as String? ?? '';
    final hasPhone    = phone.trim().isNotEmpty;

    return _SectionCard(
      title: 'Assigned Patient',
      icon: Icons.elderly_rounded,
      accentColor: AppColors.secondary,
      children: [
        _detailRow(Icons.badge_rounded,       'Full Name',   name,  theme),
        _divider(),
        _detailRow(Icons.cake_rounded,        'Age',         ageStr, theme),
        _divider(),
        _detailRow(Icons.bloodtype_rounded,   'Blood Group', blood,  theme),
        _divider(),
        _detailRow(Icons.local_hospital_rounded, 'Conditions',
            conditions.isNotEmpty ? conditions : 'Not specified', theme),
        _divider(),
        _detailRow(Icons.accessible_rounded,  'Mobility',
            mobility.isNotEmpty ? mobility : 'Not specified', theme),
        const SizedBox(height: 14),
        // Call button — same full-width outlined style
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: hasPhone ? () => _callElderly(phone) : null,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call Patient'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              disabledForegroundColor: AppColors.textMuted,
              side: BorderSide(
                color: hasPhone
                    ? AppColors.success.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── SETTINGS CARD ─────────────────────────────────────────────

  Widget _buildSettingsCard(ThemeData theme) {
    // Read dark mode state from ThemeProvider
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
          subtitle: 'Receive push notifications for alerts',
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
          theme: theme,
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
    ValueChanged<bool>? onChanged, // nullable → disables switch when null
    required ThemeData theme,
  }) {
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

  // ── ACTION BUTTONS ────────────────────────────────────────────

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
