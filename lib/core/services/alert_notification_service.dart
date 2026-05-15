import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import 'sound_service.dart';
import 'in_app_notification_overlay.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ALERT NOTIFICATION SERVICE — Centralized Sound + Popup Handler
//
// Singleton that tracks which alerts have already triggered a notification.
// Call processAlerts() from GlobalAlertCacheService whenever new data
// arrives from Firestore. On the first invocation (initial load) sounds
// are suppressed so the user isn't blasted on login.
//
// Works identically for Caregiver, Elderly and Emergency dashboards.
// ═══════════════════════════════════════════════════════════════════════════

class AlertNotificationService {
  AlertNotificationService._();
  static final AlertNotificationService instance =
      AlertNotificationService._();

  /// IDs we have already triggered a notification for.
  final Set<String> _notifiedIds = {};

  /// Whether the very first data snapshot has been received.
  /// Sounds are suppressed during this snapshot.
  bool _initialLoadDone = false;

  /// Process a fresh list of alerts from the Firestore stream.
  ///
  /// - On the *first* call (initial load): populates [_notifiedIds] silently.
  /// - On subsequent calls: plays sound + shows popup for any NEW active
  ///   alert whose id is not yet in [_notifiedIds].
  void processAlerts(List<AlertModel> alerts) {
    bool shouldNotify = false;
    AlertModel? newestAlert;

    for (final alert in alerts) {
      bool isTarget = alert.isActive || alert.isAdminMessage;
      if (isTarget && !_notifiedIds.contains(alert.id)) {
        _notifiedIds.add(alert.id);
        // Only fire sound/popup after the initial snapshot
        if (_initialLoadDone) {
          shouldNotify = true;
          // Pick the most recent unseen alert for the banner
          if (newestAlert == null ||
              (alert.timestamp != null &&
                  newestAlert.timestamp != null &&
                  alert.timestamp!.isAfter(newestAlert.timestamp!))) {
            newestAlert = alert;
          }
        }
      }
    }

    // Mark first load done after scanning
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      return;
    }

    if (shouldNotify && newestAlert != null) {
      _fireNotification(newestAlert);
    }

    _trimIfNeeded();
  }

  /// Play alert sound + show in-app popup banner.
  void _fireNotification(AlertModel alert) {
    try {
      if (alert.isAdminMessage) {
        SoundService.instance.playNotification(); // Gentle chime for admin messages
      } else {
        SoundService.instance.playAlert(); // SOS alarm for emergencies
      }
    } catch (e) {
      debugPrint('AlertNotificationService: sound error $e');
    }

    // Build contextual title and body
    final title = alert.typeLabel;
    final name = (alert.elderlyName != null && alert.elderlyName!.isNotEmpty)
        ? alert.elderlyName!
        : 'Patient';
    final body = alert.description.isNotEmpty
        ? alert.description
        : 'Alert received from $name';

    InAppNotificationOverlay.instance.show(
      messageId: alert.id,
      title: title,
      body: body,
      priority: alert.isAdminMessage ? 'low' : (alert.isHighPriority ? 'high' : 'medium'),
      iconData: alert.isAdminMessage ? Icons.message_rounded : alert.typeIcon,
      onTap: () {
        // Dismiss only — navigation is handled by individual dashboards
      },
    );
  }

  /// Trim tracked IDs to prevent unbounded memory growth.
  void _trimIfNeeded() {
    if (_notifiedIds.length > 200) {
      final keep = _notifiedIds.toList().sublist(_notifiedIds.length - 100);
      _notifiedIds
        ..clear()
        ..addAll(keep);
    }
  }

  /// Reset state — call on logout.
  void reset() {
    _notifiedIds.clear();
    _initialLoadDone = false;
  }
}
