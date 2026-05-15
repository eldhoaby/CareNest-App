import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'core/services/sound_service.dart';
import 'core/services/in_app_notification_overlay.dart';
import 'core/services/unseen_alert_service.dart';
import 'screens/splash/splash_screen.dart';

/// Global navigator key — used by InAppNotificationOverlay
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background FCM handler — runs in an isolate when app is killed or in background.
/// Shows a local notification with the custom alert_channel sound.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint("📩 Background message received: ${message.messageId}");

  // Initialize local notifications in this isolate
  final localNotif = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotif.initialize(const InitializationSettings(android: androidInit));

  // Create the channel (idempotent — Android will skip if already exists)
  await localNotif
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        'alert_channel',
        'Alerts',
        description: 'Alert notifications from SmartNest AAL system',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_sound'),
        enableVibration: true,
      ));

  final notification = message.notification;
  if (notification == null) return;

  final title = notification.title ?? '🚨 Emergency Alert';
  final body  = notification.body  ?? 'A new alert has been received';

  await localNotif.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'alert_channel',
        'Alerts',
        channelDescription: 'Alert notifications from SmartNest AAL system',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_sound'),
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize Firebase safely
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  /// Register background notification handler
  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  /// Initialize notifications
  await NotificationService.instance.init();

  /// Initialize sound service (Feature #8)
  await SoundService.instance.init();

  /// Initialize unseen alert tracking
  await UnseenAlertService.instance.init();

  /// Wire overlay service to use our navigator key
  InAppNotificationOverlay.instance.navigatorKey = navigatorKey;

  runApp(const SmartNestApp());
}

class SmartNestApp extends StatelessWidget {
  const SmartNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: '${AppConstants.appName} - Smart Assisted Living',
            theme: SmartNestTheme.lightTheme,
            darkTheme: SmartNestTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

