import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/services/firebase_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/primary_button.dart';

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
  bool isEditing = false;
  bool isSaving = false;
  bool hasLoadedInitialData = false;

  String? _inviteCode;
  bool _generatingCode = false;

  final addressController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

  @override
  void dispose() {
    addressController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _saveProfile() async {
    setState(() => isSaving = true);

    try {
      await FirebaseService.instance.updateUserProfile({
        'address': addressController.text.trim(),
        'emergencyContactName': emergencyNameController.text.trim(),
        'emergencyContactPhone': emergencyPhoneController.text.trim(),
      });

      if (!mounted) return;
      setState(() {
        isEditing = false;
        isSaving = false;
      });
      _showSnack('Profile updated successfully ✓', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showSnack('Failed to save profile', isError: true);
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
      _showSnack('Failed to generate invite code', isError: true);
    }
  }

  void _copyInviteCode() {
    if (_inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    _showSnack('Invite code copied! Share it with your caregiver.');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseService.instance.userProfileStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() ?? {};

        final name = data['name'] ?? widget.userName;
        final email = data['email'] ?? widget.userEmail;
        final role = (data['role'] ?? 'elderly').toString().toUpperCase();
        final phone = data['phone'] ?? '';
        final dobString = data['dateOfBirth'];
        final existingCode = data['inviteCode'];

        if (existingCode != null && _inviteCode == null) {
          _inviteCode = existingCode;
        }

        if (!hasLoadedInitialData) {
          addressController.text = data['address'] ?? '';
          emergencyNameController.text = data['emergencyContactName'] ?? '';
          emergencyPhoneController.text = data['emergencyContactPhone'] ?? '';
          hasLoadedInitialData = true;
        }

        DateTime? dob;
        if (dobString != null && dobString.isNotEmpty) {
          try {
            dob = DateFormat('dd MMM yyyy').parse(dobString);
          } catch (_) {}
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProfileHeader(
                name: name,
                email: email,
                role: role,
                phone: phone,
                dob: dob,
              ),
              const SizedBox(height: 24),

              // Invite Code Section
              _buildInviteCodeCard(),

              const SizedBox(height: 20),

              _buildEditableField(
                label: 'Home Address',
                controller: addressController,
                icon: Icons.home_outlined,
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                label: 'Emergency Contact Name',
                controller: emergencyNameController,
                icon: Icons.contact_emergency_outlined,
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                label: 'Emergency Contact Phone',
                controller: emergencyPhoneController,
                icon: Icons.phone_in_talk_outlined,
                keyboard: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),

              if (!isEditing)
                PrimaryButton(
                  text: 'Edit Profile',
                  onPressed: () => setState(() => isEditing = true),
                )
              else
                PrimaryButton(
                  text: isSaving ? 'Saving...' : 'Save Changes',
                  onPressed: isSaving ? null : _saveProfile,
                ),

              const SizedBox(height: 12),

              PrimaryButton(
                text: 'Sign Out',
                color: Colors.grey,
                onPressed: widget.onLogout,
              ),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader({
    required String name,
    required String email,
    required String role,
    required String phone,
    DateTime? dob,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.08),
            const Color(0xFF3B82F6).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            name.isNotEmpty ? name : 'User',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          if (phone.isNotEmpty)
            Text(phone, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          if (dob != null)
            Text(
              'Age ${_calculateAge(dob)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Caregiver Invite Code',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with your caregiver so they can link their account to yours.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 14),

          if (_inviteCode != null) ...[
            // Show code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Center(
                child: Text(
                  _inviteCode!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyInviteCode,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generatingCode ? null : _generateInviteCode,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('New Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingCode ? null : _generateInviteCode,
                icon: _generatingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.vpn_key),
                label: Text(
                    _generatingCode ? 'Generating...' : 'Generate Invite Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}