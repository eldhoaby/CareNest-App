import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/alert_model.dart';
import 'alert_notification_service.dart';
import 'firebase_service.dart';
import 'unseen_alert_service.dart';

/// Centralized cache for active/recent alerts to avoid redundant Firestore listeners.
class GlobalAlertCacheService extends ChangeNotifier {
  GlobalAlertCacheService._();
  static final GlobalAlertCacheService instance = GlobalAlertCacheService._();

  StreamSubscription? _alertsSub;
  StreamSubscription? _notifsSub;
  List<String> _currentTargetUids = [];

  final ValueNotifier<List<AlertModel>> alertsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadedNotifier = ValueNotifier(false);

  List<AlertModel> _latestAlerts = [];
  List<AlertModel> _latestNotifs = [];

  void _updateCombinedAlerts() {
    final combined = [..._latestAlerts, ..._latestNotifs];
    combined.sort((a, b) => (b.timestamp ?? DateTime.now())
        .compareTo(a.timestamp ?? DateTime.now()));

    // Ensure uniqueness by ID just in case
    final Map<String, AlertModel> unique = {};
    for (var model in combined) {
      if (!unique.containsKey(model.id)) {
        unique[model.id] = model;
      }
    }
    
    final finalAlerts = unique.values.toList();
    isLoadedNotifier.value = true;
    alertsNotifier.value = finalAlerts;

    final activeIds = finalAlerts.where((a) => a.isActive).map((a) => a.id).toList();
    UnseenAlertService.instance.updateAlerts(activeIds);
    AlertNotificationService.instance.processAlerts(finalAlerts);
  }

  /// Listens to live alerts for the specified user(s) and caches them in memory.
  /// If the target UIDs change, the old stream is canceled and a new one is started.
  void startListening(List<String> targetUids) {
    if (targetUids.isEmpty) {
      alertsNotifier.value = [];
      isLoadedNotifier.value = true;
      return;
    }

    if (listEquals(_currentTargetUids, targetUids) && _alertsSub != null && _notifsSub != null) {
      return;
    }

    _alertsSub?.cancel();
    _notifsSub?.cancel();
    
    _currentTargetUids = List.from(targetUids);
    isLoadedNotifier.value = false;
    _latestAlerts = [];
    _latestNotifs = [];

    _alertsSub = FirebaseService.instance.allAlertsStream().listen(
      (snapshot) {
        _latestAlerts = snapshot.docs.map((doc) => AlertModel.fromDoc(doc)).toList();
        _updateCombinedAlerts();
      },
      onError: (e) {
        debugPrint('Alert stream error: $e');
        isLoadedNotifier.value = true;
      },
    );

    _notifsSub = FirebaseService.instance.allNotificationsStream().listen(
      (snapshot) {
        _latestNotifs = snapshot.docs
            .map((doc) => AlertModel.fromDoc(doc))
            .where((msg) {
              final target = msg.target?.toLowerCase() ?? '';
              if (target == 'all users' || target == 'all' || target.isEmpty) return true;
              if (_currentTargetUids.any((uid) => target.contains(uid.toLowerCase()))) return true;
              return false;
            })
            .toList();
        _updateCombinedAlerts();
      },
      onError: (e) {
        debugPrint('Notification stream error: $e');
        isLoadedNotifier.value = true;
      },
    );
  }

  void stopListening() {
    _alertsSub?.cancel();
    _alertsSub = null;
    _notifsSub?.cancel();
    _notifsSub = null;
    _currentTargetUids = [];
    alertsNotifier.value = [];
    isLoadedNotifier.value = false;
    _latestAlerts = [];
    _latestNotifs = [];
  }

  /// Inject an optimistic alert before Firestore stream catches up.
  /// Ensures instant UI update.
  void addOptimisticAlert(AlertModel alert) {
    final current = List<AlertModel>.from(alertsNotifier.value);
    final idx = current.indexWhere((a) => a.id == alert.id);
    if (idx >= 0) {
      current[idx] = alert;
    } else {
      current.insert(0, alert);
    }
    
    // Sort recent first to mimic Firestore stream
    current.sort((a, b) => (b.timestamp ?? DateTime.now())
        .compareTo(a.timestamp ?? DateTime.now()));
        
    alertsNotifier.value = current;

    // Update unseen alerts globally for optimistic updates
    final activeIds = current.where((a) => a.isActive).map((a) => a.id).toList();
    UnseenAlertService.instance.updateAlerts(activeIds);

    // Centralized sound + popup
    AlertNotificationService.instance.processAlerts(current);
  }
}
