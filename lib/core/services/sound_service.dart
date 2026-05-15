import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SOUND SERVICE — Custom Audio Notification System
//
// Uses `audioplayers` for instant in-app playback of custom sounds.
// Uses `flutter_local_notifications` for background/notification sounds.
//
// Alert sound: 3 ascending chimes — for incoming alerts
// SOS sound:   Urgent pulsing alarm — for SOS button press
// ═══════════════════════════════════════════════════════════════════════════

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _soundEnabledKey = 'sound_enabled';
  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;

  // ── Audio players (reused to avoid re-initialization) ──────────
  AudioPlayer? _alertPlayer;
  AudioPlayer? _sosPlayer;

  // ── Notification plugin (for background sounds) ────────────────
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // ── Notification channels ──────────────────────────────────────
  static const _sosChannel = AndroidNotificationChannel(
    'smartnest_sos_sound',
    'SOS Alerts',
    description: 'Emergency SOS alert sound',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('sos'),
  );

  static const _alertChannel = AndroidNotificationChannel(
    'alert_channel',
    'Alert Notifications',
    description: 'Alert notification sound',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('alert_sound'),
  );

  static const _resolvedChannel = AndroidNotificationChannel(
    'smartnest_resolved_sound',
    'Resolved Alerts',
    description: 'Alert resolved confirmation sound',
    importance: Importance.high,
    playSound: true,
    enableVibration: false,
  );

  // ═════════════════════════════════════════════════════════════════
  // INIT
  // ═════════════════════════════════════════════════════════════════

  /// Initialize audio players, load preferences, create channels
  Future<void> init() async {
    try {
      // Load preference
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;

      // Pre-create audio players
      _alertPlayer = AudioPlayer();
      _sosPlayer = AudioPlayer();

      // Set audio contexts for reliable playback
      await _alertPlayer!.setReleaseMode(ReleaseMode.stop);
      await _sosPlayer!.setReleaseMode(ReleaseMode.stop);

      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotif.initialize(initSettings);

      // Create notification channels
      final androidPlugin = _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_sosChannel);
      await androidPlugin?.createNotificationChannel(_alertChannel);
      await androidPlugin?.createNotificationChannel(_resolvedChannel);

      debugPrint('✅ SoundService initialized');
    } catch (e) {
      debugPrint('SoundService init error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // PREFERENCES
  // ═════════════════════════════════════════════════════════════════

  /// Update sound preference
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, enabled);
    } catch (e) {
      debugPrint('SoundService setSoundEnabled error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // IN-APP PLAYBACK — instant, low-latency
  // ═════════════════════════════════════════════════════════════════

  /// Play alert sound (ascending chimes) — for incoming alerts
  Future<void> playAlert() async {
    if (!_soundEnabled) return;

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      // Stop any currently playing alert first
      await _alertPlayer?.stop();
      await _alertPlayer?.play(AssetSource('sounds/alert_sound.mp3'));
    } catch (e) {
      debugPrint('SoundService playAlert error: $e');
    }
  }

  /// Play notification sound (lighter chime) — for non-critical alerts
  /// Uses notification.mpeg for a subtler, less alarming tone
  Future<void> playNotification() async {
    if (!_soundEnabled) return;

    HapticFeedback.lightImpact();

    try {
      await _alertPlayer?.stop();
      await _alertPlayer?.play(AssetSource('sounds/notification.mpeg'));
    } catch (e) {
      debugPrint('SoundService playNotification error: $e');
    }
  }

  /// Play SOS sound (urgent alarm) — for SOS button press
  /// This plays immediately for maximum responsiveness
  Future<void> playSOS() async {
    if (!_soundEnabled) return;

    // Heavy haptic for emergency
    HapticFeedback.heavyImpact();

    try {
      // Stop any previous sound first
      await _sosPlayer?.stop();
      await _alertPlayer?.stop(); // Also stop alert if playing
      await _sosPlayer?.play(AssetSource('sounds/sos.mpeg'));
    } catch (e) {
      debugPrint('SoundService playSOS error: $e');
    }
  }

  /// Stop all currently playing sounds
  Future<void> stopAll() async {
    try {
      await _alertPlayer?.stop();
      await _sosPlayer?.stop();
    } catch (e) {
      debugPrint('SoundService stopAll error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // NOTIFICATION-BASED SOUND — for background + system tray
  // ═════════════════════════════════════════════════════════════════

  /// Play SOS sent sound + vibration (in-app only).
  /// System OS notification removed — the in-app banner from
  /// AlertNotificationService handles the visible popup.
  Future<void> playSosSent() async {
    if (!_soundEnabled) return;

    HapticFeedback.heavyImpact();

    // Play in-app sound immediately (no system notification)
    await playSOS();
  }

  /// Play alert received notification with custom sound
  /// Used when an alert arrives via FCM in foreground
  Future<void> playAlertReceived({
    String title = '🔔 Alert',
    String body = 'New alert received',
    bool playSound = true,
  }) async {
    if (playSound && _soundEnabled) {
      HapticFeedback.mediumImpact();
      // Play in-app sound immediately
      await playAlert();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'alert_channel',
        'Alert Notifications',
        channelDescription: 'Alert notification sound',
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound && _soundEnabled,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        timeoutAfter: 4000,
      );

      await _localNotif.show(
        9003,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('SoundService playAlertReceived notification error: $e');
    }
  }

  /// Play alert resolved sound — gentle notification
  Future<void> playAlertResolved() async {
    if (!_soundEnabled) return;

    HapticFeedback.mediumImpact();

    try {
      const androidDetails = AndroidNotificationDetails(
        'smartnest_resolved_sound',
        'Resolved Alerts',
        channelDescription: 'Alert resolved confirmation sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: false,
        icon: '@mipmap/ic_launcher',
        timeoutAfter: 2000,
      );

      await _localNotif.show(
        9002,
        '✅ Alert Resolved',
        'Safety alert has been resolved',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('SoundService playAlertResolved error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═════════════════════════════════════════════════════════════════

  /// Dispose audio players when no longer needed
  Future<void> dispose() async {
    await _alertPlayer?.dispose();
    await _sosPlayer?.dispose();
    _alertPlayer = null;
    _sosPlayer = null;
  }
}
