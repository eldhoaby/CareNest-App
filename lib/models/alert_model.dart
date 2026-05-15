import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';

// Removed AlertType enum as type is now fully dynamic string
enum AlertPriority { high, medium, low }

enum AlertStatus { active, responded, resolved }

/// Alert severity category for UI filtering
enum AlertCategory { critical, warning, info, resolved }

class AlertModel {
  final String id;
  final String elderlyId;
  final String? elderlyName;
  final String? address;
  final String type;
  final AlertPriority priority;
  final String description;
  final AlertStatus status;
  final DateTime? timestamp;
  final DateTime? resolvedAt;
  final String? respondedBy;
  final String? target;
  final bool isAdminMessage;

  const AlertModel({
    required this.id,
    required this.elderlyId,
    this.elderlyName,
    this.address,
    required this.type,
    required this.priority,
    required this.description,
    required this.status,
    this.timestamp,
    this.resolvedAt,
    this.respondedBy,
    this.target,
    this.isAdminMessage = false,
  });

  factory AlertModel.fromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Handle timestamp that might be a String, int, or FieldValue serverTimestamp instead of Timestamp object
      DateTime? parsedTimestamp;
      final rawTs = data['timestamp'] ?? data['createdAt'];
      if (rawTs is Timestamp) {
        parsedTimestamp = rawTs.toDate();
      } else if (rawTs is String) {
        parsedTimestamp = DateTime.tryParse(rawTs);
      } else if (rawTs is int) {
        parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
      }

      // Read either 'status' or default to 'active' mapping
      String rawStatus = (data['status'] ?? data['state'] ?? 'active').toString();
      
      // First, extract raw fields
      String? rawTitle = data['title']?.toString();
      String rawType = (data['type'] ?? data['name'] ?? 'Notification').toString();
      String rawDesc = (data['description'] ?? data['message'] ?? data['body'] ?? '').toString();
      
      // Determine if it's an admin message before normalizing
      bool isAdmin = rawStatus.toLowerCase() == 'sent' || data.containsKey('target') || doc.reference.path.contains('notifications');

      // For admin notifications, map the Title to the big text block (description) 
      // and map the actual message content to the subtitle block (type) for optimal UI rendering
      if (isAdmin && rawTitle != null && rawTitle.isNotEmpty) {
        rawType = rawDesc.isNotEmpty ? rawDesc : rawType;
        rawDesc = rawTitle;
      } else if (rawTitle != null && rawTitle.isNotEmpty) {
        // Legacy fallback for non-admin alerts using title field
        rawType = rawTitle;
      }



      return AlertModel(
        id: doc.id,
        elderlyId: (data['elderlyId'] ?? data['userId'] ?? data['uid'] ?? '').toString(),
        elderlyName: data['elderlyName']?.toString(),
        address: data['address']?.toString(),
        type: rawType,
        priority: _parsePriority((data['priority'] ?? data['severity'] ?? '').toString()),
        description: rawDesc,
        status: _parseStatus(rawStatus),
        timestamp: parsedTimestamp ?? DateTime.now(), // Fallback to now if missing so it shows up in the UI
        resolvedAt: data['resolvedAt'] is Timestamp ? (data['resolvedAt'] as Timestamp).toDate() : null,
        respondedBy: data['respondedBy']?.toString(),
        target: data['target']?.toString(),
        isAdminMessage: isAdmin,
      );
    } catch (e, stack) {
      debugPrint('Error parsing AlertModel from doc ${doc.id}: $e\n$stack');
      // Return a safe fallback rather than crashing the entire stream
      return AlertModel(
        id: doc.id,
        elderlyId: '',
        type: 'Unknown Alert',
        priority: AlertPriority.low,
        description: 'Failed to parse alert data',
        status: AlertStatus.active,
        timestamp: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'elderlyId': elderlyId,
      'userId': elderlyId, // Keep for backward compatibility if needed
      if (elderlyName != null) 'elderlyName': elderlyName,
      if (address != null) 'address': address,
      'type': type,
      'priority': priority.name,
      'description': description,
      'status': status.name,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  static AlertPriority _parsePriority(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return AlertPriority.high;
      case 'medium':
        return AlertPriority.medium;
      case 'low':
      default:
        return AlertPriority.low;
    }
  }

  static AlertStatus _parseStatus(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return AlertStatus.active;
      case 'responded':
        return AlertStatus.responded;
      case 'resolved':
      case 'sent':
        return AlertStatus.resolved;
      default:
        return AlertStatus.active;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DISPLAY HELPERS
  // ═══════════════════════════════════════════════════════════════

  AlertCategory get category {
    if (status == AlertStatus.resolved) return AlertCategory.resolved;
    if (priority == AlertPriority.high) return AlertCategory.critical;
    if (priority == AlertPriority.medium) return AlertCategory.warning;
    return AlertCategory.info; // low or default
  }

  String get typeLabel {
    // Directly use from Firestore without hardcoding
    if (type.isEmpty) return 'Alert';
    
    // Simple format like "doorOpen" -> "Door Open" or uppercase
    final formatted = type.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
    if (formatted.length > 1) {
      return formatted[0].toUpperCase() + formatted.substring(1);
    }
    return formatted.toUpperCase();
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
        return AppColors.danger;
      case AlertPriority.medium:
        return AppColors.warning;
      case AlertPriority.low:
        return const Color(0xFF3B82F6);
    }
  }

  Color get categoryColor {
    switch (category) {
      case AlertCategory.critical:
        return AppColors.danger;
      case AlertCategory.warning:
        return AppColors.warning;
      case AlertCategory.info:
        return const Color(0xFF3B82F6);
      case AlertCategory.resolved:
        return AppColors.success;
    }
  }

  Color get statusColor {
    switch (status) {
      case AlertStatus.active:
        return AppColors.danger;
      case AlertStatus.responded:
        return AppColors.warning;
      case AlertStatus.resolved:
        return AppColors.success;
    }
  }

  IconData get typeIcon {
    final t = type.toLowerCase();
    if (t.contains('fall')) return Icons.personal_injury_rounded;
    if (t.contains('inactiv') || t.contains('movement')) return Icons.hourglass_bottom_rounded;
    if (t.contains('sos') || t.contains('emergency')) return Icons.sos_rounded;
    if (t.contains('door')) return Icons.door_front_door_rounded;
    if (t.contains('heart')) return Icons.favorite_rounded;
    if (t.contains('breath')) return Icons.air_rounded;
    if (t.contains('smoke') || t.contains('fire')) return Icons.fire_extinguisher_rounded;
    return Icons.notification_important_rounded;
  }

  /// Create a copy with modified fields (used for optimistic UI updates)
  AlertModel copyWith({
    String? id,
    String? elderlyId,
    String? elderlyName,
    String? address,
    String? type,
    AlertPriority? priority,
    String? description,
    AlertStatus? status,
    DateTime? timestamp,
    DateTime? resolvedAt,
    String? respondedBy,
  }) {
    return AlertModel(
      id: id ?? this.id,
      elderlyId: elderlyId ?? this.elderlyId,
      elderlyName: elderlyName ?? this.elderlyName,
      address: address ?? this.address,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      respondedBy: respondedBy ?? this.respondedBy,
    );
  }

  bool get isHighPriority => priority == AlertPriority.high;
  bool get isActive => status == AlertStatus.active;
  bool get isResolved => status == AlertStatus.resolved;

  String get timeAgo {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String get formattedTime {
    if (timestamp == null) return '';
    return _formatDt(timestamp!);
  }

  String get formattedResolvedAt {
    if (resolvedAt == null) return 'N/A';
    return _formatFullDt(resolvedAt!);
  }

  String get resolvedAtTimeAgo {
    if (resolvedAt == null) return '';
    final diff = DateTime.now().difference(resolvedAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _formatDt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $ampm';
  }

  static String _formatFullDt(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$m $ampm';
  }
}
