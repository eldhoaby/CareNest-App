import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../widgets/premium/glass_card.dart';
import '../../../widgets/global_loader.dart';

class LinkedCaregiversSection extends StatelessWidget {
  final String elderlyUid;

  const LinkedCaregiversSection({
    super.key,
    required this.elderlyUid,
  });

  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    
    // Clean phone number (remove spaces, dashes)
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot launch dialer')),
          );
        }
      }
    } catch (e) {
      debugPrint('Launch url error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (elderlyUid.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Linked Caregivers', Icons.family_restroom_rounded),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'caregiver')
              .where('linkedElderlyUid', isEqualTo: elderlyUid)
              .snapshots(),
          // NOTE: If caregivers store linkedElderlyUid as an array, use:
          // .where('linkedElderlyUid', arrayContains: elderlyUid)
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const GlobalLoader(isFullScreen: false);
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 16,
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded,
                        color: AppColors.textMuted.withValues(alpha: 0.5), size: 28),
                    const SizedBox(width: 14),
                    const Text(
                      'No caregivers linked yet',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Unknown Caregiver';
                final phone = data['phone'] ?? '';
                final relationship = data['relationship'] ?? 'Caregiver';

                final isValidPhone = phone.toString().trim().isNotEmpty;

                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_outline_rounded,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.link_rounded,
                                        size: 14, color: AppColors.primarySoft),
                                    const SizedBox(width: 4),
                                    Text(
                                      relationship,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primarySoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: isValidPhone
                              ? () => _makePhoneCall(context, phone)
                              : null,
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                            disabledForegroundColor: AppColors.textMuted,
                            side: BorderSide(
                                color: isValidPhone
                                    ? AppColors.success.withValues(alpha: 0.3)
                                    : AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
           title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
