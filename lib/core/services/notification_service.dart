import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const _channel = AndroidNotificationChannel(
    'smartnest_alerts',
    'SmartNest Alerts',
    description: 'Alert notifications from SmartNest AAL system',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize notification services
  Future<void> init() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      debugPrint('Notification permission: ${settings.authorizationStatus}');

      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channel on Android
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Get and log FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('=================================');
        debugPrint('FCM TOKEN:');
        debugPrint(token);
        debugPrint('=================================');
      }

      // Foreground notification handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Notification tap when app in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Handle foreground FCM messages → show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    showLocalNotification(
      title: notification.title ?? 'SmartNest Alert',
      body: notification.body ?? '',
      priority: message.data['priority'] ?? 'medium',
    );
  }

  /// Handle notification tap
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('📲 Notification opened: ${message.notification?.title}');
    // Navigation can be handled here via a global navigator key
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped: ${response.payload}');
  }

  /// Show a local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String priority = 'medium',
  }) async {
    final isHigh = priority == 'high';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: isHigh ? Importance.max : Importance.high,
      priority: isHigh ? Priority.max : Priority.high,
      color: isHigh ? const Color(0xFFEF4444) : const Color(0xFF2A7FFF),
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Register FCM token after login + subscribe to role topic
  Future<void> registerTokenAfterLogin(String role) async {
    try {
      // Save token to Firestore
      await FirebaseService.instance.initFCM();

      // Subscribe to role-based topic
      await FirebaseService.instance.subscribeToRoleTopic(role);
    } catch (e) {
      debugPrint('Token registration error: $e');
    }
  }
}