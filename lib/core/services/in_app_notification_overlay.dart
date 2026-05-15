import 'package:flutter/material.dart';

import '../../widgets/premium/in_app_notification_banner.dart';

// ═══════════════════════════════════════════════════════════════════════════
// IN-APP NOTIFICATION OVERLAY — Singleton Manager (Stacking support)
//
// Shows premium floating notification banners on top of any screen.
// Supports up to 3 stacked notifications with independent auto-dismiss.
// Uses the global navigator's overlay — works from anywhere in the app.
// ═══════════════════════════════════════════════════════════════════════════

class InAppNotificationOverlay {
  InAppNotificationOverlay._();
  static final InAppNotificationOverlay instance =
      InAppNotificationOverlay._();

  /// Must be set from MaterialApp's navigatorKey
  GlobalKey<NavigatorState>? navigatorKey;

  /// Maximum number of stacked notifications
  static const int _maxStack = 3;

  /// Currently displayed overlay entries (newest first)
  final List<_NotificationEntry> _stack = [];

  /// Track shown message IDs to avoid duplicates
  final Set<String> _recentMessageIds = {};

  /// Show an in-app notification banner.
  ///
  /// [messageId] — Unique ID to prevent duplicate notifications.
  /// [title] — Notification title.
  /// [body] — Notification body text.
  /// [priority] — 'high', 'medium', or 'low'.
  /// [iconData] — Optional icon to display.
  /// [onTap] — Callback when user taps the banner.
  void show({
    required String messageId,
    required String title,
    required String body,
    String priority = 'medium',
    IconData? iconData,
    VoidCallback? onTap,
  }) {
    // Deduplicate — skip if we showed this exact message recently
    if (_recentMessageIds.contains(messageId)) return;
    _recentMessageIds.add(messageId);

    // Clean up old IDs to prevent memory growth
    if (_recentMessageIds.length > 50) {
      _recentMessageIds.clear();
    }

    // Remove oldest if we've hit the stack limit
    if (_stack.length >= _maxStack) {
      _dismissEntry(_stack.last);
    }

    // Get the overlay from the navigator
    final overlay = navigatorKey?.currentState?.overlay;
    if (overlay == null) {
      debugPrint('InAppNotificationOverlay: No overlay available');
      return;
    }

    late final _NotificationEntry entry;

    final overlayEntry = OverlayEntry(
      builder: (context) => InAppNotificationBanner(
        title: title,
        body: body,
        priority: priority,
        iconData: iconData,
        stackIndex: _stack.indexOf(entry).clamp(0, _maxStack - 1),
        onTap: () {
          _dismissEntry(entry);
          onTap?.call();
        },
        onDismiss: () => _dismissEntry(entry),
      ),
    );

    entry = _NotificationEntry(
      id: messageId,
      overlayEntry: overlayEntry,
    );

    // Insert at start (newest first)
    _stack.insert(0, entry);

    overlay.insert(overlayEntry);

    // Rebuild all entries to update their stackIndex
    _rebuildStack();
  }

  /// Dismiss a specific notification entry
  void _dismissEntry(_NotificationEntry entry) {
    if (!_stack.contains(entry)) return;
    entry.overlayEntry.remove();
    _stack.remove(entry);
    _rebuildStack();
  }

  /// Mark all overlay entries as needing rebuild (to update stackIndex)
  void _rebuildStack() {
    for (final entry in _stack) {
      entry.overlayEntry.markNeedsBuild();
    }
  }

  /// Dismiss all currently displayed banners
  void dismissAll() {
    for (final entry in List.from(_stack)) {
      entry.overlayEntry.remove();
    }
    _stack.clear();
  }

  /// Reset state (e.g., on logout)
  void reset() {
    dismissAll();
    _recentMessageIds.clear();
  }
}

/// Internal model for tracking a notification in the stack
class _NotificationEntry {
  final String id;
  final OverlayEntry overlayEntry;

  _NotificationEntry({
    required this.id,
    required this.overlayEntry,
  });
}
