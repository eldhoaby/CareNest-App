import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// UNSEEN ALERT SERVICE — Tracks which alerts have been seen by the user.
//
// Persists seen IDs in SharedPreferences. Exposes a ValueNotifier<int>
// so the notification bell badge can reactively update.
//
// Usage:
//   - Home tabs call updateAlerts(alerts) to recalculate unseen count
//   - Alert tabs call markAllSeen(alerts) when user views the full list
// ═══════════════════════════════════════════════════════════════════════════

class UnseenAlertService {
  UnseenAlertService._();
  static final UnseenAlertService instance = UnseenAlertService._();

  static const _prefsKey = 'seen_alert_ids';

  /// Reactive unseen count — bind to this from bell badge
  final ValueNotifier<int> unseenCount = ValueNotifier<int>(0);

  /// In-memory cache of seen IDs
  final Set<String> _seenIds = {};

  /// Whether we've loaded from disk yet
  bool _initialized = false;

  /// Initialize from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? [];
    _seenIds.addAll(stored);
    _initialized = true;
  }

  /// Call from home tab alert streams — recalculates unseen count.
  /// Pass only ACTIVE alerts (not resolved).
  void updateAlerts(List<String> activeAlertIds) {
    int unseen = 0;
    for (final id in activeAlertIds) {
      if (!_seenIds.contains(id)) {
        unseen++;
      }
    }
    unseenCount.value = unseen;
  }

  /// Mark all current active alerts as "seen".
  /// Call this when the user opens the Alerts tab.
  Future<void> markAllSeen(List<String> activeAlertIds) async {
    _seenIds.addAll(activeAlertIds);
    unseenCount.value = 0;
    await _persist();
  }

  /// Persist to SharedPreferences.
  /// We keep only the last 500 IDs to prevent unbounded growth.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _seenIds.toList();
    if (list.length > 500) {
      final trimmed = list.sublist(list.length - 500);
      _seenIds
        ..clear()
        ..addAll(trimmed);
    }
    await prefs.setStringList(_prefsKey, _seenIds.toList());
  }

  /// Reset state (e.g. on logout)
  Future<void> reset() async {
    _seenIds.clear();
    unseenCount.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
