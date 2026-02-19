import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:aal_app/core/theme/app_theme.dart';
import '../../widgets/primary_button.dart';

class ElderlyProfileTab extends StatefulWidget {
  const ElderlyProfileTab({super.key});

  @override
  State<ElderlyProfileTab> createState() => _ElderlyProfileTabState();
}

class _ElderlyProfileTabState extends State<ElderlyProfileTab> {

  bool isEditing = false;
  bool locationSharing = false;
  bool hasLoadedInitialData = false;

  final addressController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'address': addressController.text.trim(),
      'emergencyName': emergencyNameController.text.trim(),
      'emergencyPhone': emergencyPhoneController.text.trim(),
      'locationSharing': locationSharing,
    });

    setState(() => isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile updated successfully"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final name = data['name'] ?? '';
        final dobString = data['dob'];
        final address = data['address'] ?? '';
        final emergencyName = data['emergencyName'] ?? '';
        final emergencyPhone = data['emergencyPhone'] ?? '';
        final firestoreLocationSharing = data['locationSharing'] ?? false;

        // ✅ Load initial values ONLY ONCE
        if (!hasLoadedInitialData) {
          addressController.text = address;
          emergencyNameController.text = emergencyName;
          emergencyPhoneController.text = emergencyPhone;
          locationSharing = firestoreLocationSharing;
          hasLoadedInitialData = true;
        }

        DateTime? dob;
        if (dobString != null) {
          dob = DateFormat('dd MMM yyyy').parse(dobString);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [

              // =========================
              // PROFILE HEADER
              // =========================

              Container(
                padding: const EdgeInsets.all(28),
                decoration: SafeNestTheme.glassCard(Colors.blue),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dob != null
                          ? "Age: ${_calculateAge(dob)} years"
                          : "Age not available",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // =========================
              // ADDRESS
              // =========================

              _buildEditableField(
                label: "Address",
                controller: addressController,
              ),

              const SizedBox(height: 20),

              // =========================
              // EMERGENCY NAME
              // =========================

              _buildEditableField(
                label: "Emergency Contact Name",
                controller: emergencyNameController,
              ),

              const SizedBox(height: 20),

              // =========================
              // EMERGENCY PHONE
              // =========================

              _buildEditableField(
                label: "Emergency Contact Phone",
                controller: emergencyPhoneController,
                keyboard: TextInputType.phone,
              ),

              const SizedBox(height: 20),

              // =========================
              // LOCATION SHARING
              // =========================

              Container(
                padding: const EdgeInsets.all(20),
                decoration: SafeNestTheme.glassCard(Colors.orange),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Live Location Sharing",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: locationSharing,
                      onChanged: isEditing
                          ? (value) {
                        setState(() {
                          locationSharing = value;
                        });
                      }
                          : null,
                    )
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =========================
              // EDIT / SAVE
              // =========================

              if (!isEditing)
                PrimaryButton(
                  text: "Edit Profile",
                  onPressed: () => setState(() => isEditing = true),
                )
              else
                PrimaryButton(
                  text: "Save Changes",
                  onPressed: _saveProfile,
                ),

              const SizedBox(height: 24),

              // =========================
              // LOGOUT
              // =========================

              PrimaryButton(
                text: "Logout",
                color: Colors.grey,
                onPressed: _logout,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboard,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SafeNestTheme.glassCard(Colors.purple),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
