import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AlertType { fall, inactivity, sos }

enum AlertPriority { high, medium, low }

enum AlertStatus { active, responded, resolved }

class AlertModel {
  final String id;
  final String userId;
  final String? elderlyName;
  final AlertType type;
  final AlertPriority priority;
  final String description;
  final AlertStatus status;
  final DateTime? timestamp;
  final DateTime? resolvedAt;
  final String? respondedBy;

  const AlertModel({
    required this.id,
    required this.userId,
    this.elderlyName,
    required this.type,
    required this.priority,
    required this.description,
    required this.status,
    this.timestamp,
    this.resolvedAt,
    this.respondedBy,
  });

  factory AlertModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AlertModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      elderlyName: data['elderlyName'],
      type: _parseType(data['type'] ?? ''),
      priority: _parsePriority(data['priority'] ?? ''),
      description: data['description'] ?? '',
      status: _parseStatus(data['status'] ?? ''),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      respondedBy: data['respondedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (elderlyName != null) 'elderlyName': elderlyName,
      'type': type.name,
      'priority': priority.name,
      'description': description,
      'status': status.name,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  static AlertType _parseType(String value) {
    switch (value.toLowerCase()) {
      case 'fall':
        return AlertType.fall;
      case 'inactivity':
        return AlertType.inactivity;
      case 'sos':
        return AlertType.sos;
      default:
        return AlertType.sos;
    }
  }

  static AlertPriority _parsePriority(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return AlertPriority.high;
      case 'medium':
        return AlertPriority.medium;
      case 'low':
        return AlertPriority.low;
      default:
        return AlertPriority.medium;
    }
  }

  static AlertStatus _parseStatus(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return AlertStatus.active;
      case 'responded':
        return AlertStatus.responded;
      case 'resolved':
        return AlertStatus.resolved;
      default:
        return AlertStatus.active;
    }
  }

  /// Display helpers
  String get typeLabel {
    switch (type) {
      case AlertType.fall:
        return '🚨 Fall Detected';
      case AlertType.inactivity:
        return '⏰ Inactivity Alert';
      case AlertType.sos:
        return '🆘 Emergency SOS';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case AlertPriority.high:
        return 'HIGH';
      case AlertPriority.medium:
        return 'MEDIUM';
      case AlertPriority.low:
        return 'LOW';
    }
  }

  String get statusLabel {
    switch (status) {
      case AlertStatus.active:
        return 'Active';
      case AlertStatus.responded:
        return 'Responded';
      case AlertStatus.resolved:
        return 'Resolved';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case AlertPriority.high:
        return const Color(0xFFEF4444);
      case AlertPriority.medium:
        return const Color(0xFFF59E0B);
      case AlertPriority.low:
        return const Color(0xFF3B82F6);
    }
  }

  Color get statusColor {
    switch (status) {
      case AlertStatus.active:
        return const Color(0xFFEF4444);
      case AlertStatus.responded:
        return const Color(0xFFF59E0B);
      case AlertStatus.resolved:
        return const Color(0xFF22C55E);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case AlertType.fall:
        return Icons.personal_injury;
      case AlertType.inactivity:
        return Icons.hourglass_bottom;
      case AlertType.sos:
        return Icons.sos;
    }
  }

  bool get isHighPriority => priority == AlertPriority.high;
  bool get isActive => status == AlertStatus.active;

  String get timeAgo {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
