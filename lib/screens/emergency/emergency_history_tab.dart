import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firebase_service.dart';
import '../../models/alert_model.dart';
import '../../widgets/alert_card.dart';

class EmergencyHistoryTab extends StatefulWidget {
  final String userId;

  const EmergencyHistoryTab({super.key, required this.userId});

  @override
  State<EmergencyHistoryTab> createState() => _EmergencyHistoryTabState();
}

class _EmergencyHistoryTabState extends State<EmergencyHistoryTab> {
  String _filter = 'all'; // all, fall, sos, inactivity

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(
            'Alert History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Complete log of all past alerts',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),

        // Filter row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('🚨 Fall', 'fall'),
                const SizedBox(width: 8),
                _filterChip('🆘 SOS', 'sos'),
                const SizedBox(width: 8),
                _filterChip('⏰ Inactivity', 'inactivity'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Alert list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.instance.allAlertsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('No alert history yet',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              var alerts = snapshot.data!.docs
                  .map((doc) => AlertModel.fromDoc(doc))
                  .toList();

              // Apply type filter
              if (_filter != 'all') {
                alerts = alerts
                    .where((a) => a.type.name == _filter)
                    .toList();
              }

              if (alerts.isEmpty) {
                return Center(
                  child: Text('No $_filter alerts found',
                      style: const TextStyle(color: Colors.grey)),
                );
              }

              // Summary stats
              final activeCount =
                  alerts.where((a) => a.isActive).length;
              final resolvedCount =
                  alerts.where((a) => a.status == AlertStatus.resolved).length;

              return Column(
                children: [
                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _statBadge(
                          'Total',
                          '${alerts.length}',
                          const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 10),
                        _statBadge(
                          'Active',
                          '$activeCount',
                          const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 10),
                        _statBadge(
                          'Resolved',
                          '$resolvedCount',
                          const Color(0xFF22C55E),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: alerts.length,
                      itemBuilder: (_, i) {
                        return AlertCard(
                          alert: alerts[i],
                          showActions: false,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEF4444) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF4444)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
