import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onRespond;
  final VoidCallback? onResolve;
  final bool showActions;

  const AlertCard({
    super.key,
    required this.alert,
    this.onRespond,
    this.onResolve,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: alert.priorityColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: alert.priorityColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: alert.priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    alert.typeIcon,
                    color: alert.priorityColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.typeLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (alert.elderlyName != null)
                        Text(
                          alert.elderlyName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                // Priority + Status badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _badge(alert.priorityLabel, alert.priorityColor),
                    const SizedBox(height: 4),
                    _badge(alert.statusLabel, alert.statusColor),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Description
            Text(
              alert.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),

            const SizedBox(height: 8),

            // Timestamp
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  alert.timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            // Action buttons
            if (showActions && alert.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onRespond != null)
                    Expanded(
                      child: _actionButton(
                        label: 'Respond',
                        color: const Color(0xFFF59E0B),
                        icon: Icons.reply,
                        onTap: onRespond!,
                      ),
                    ),
                  if (onRespond != null && onResolve != null)
                    const SizedBox(width: 10),
                  if (onResolve != null)
                    Expanded(
                      child: _actionButton(
                        label: 'Resolve',
                        color: const Color(0xFF22C55E),
                        icon: Icons.check_circle_outline,
                        onTap: onResolve!,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
