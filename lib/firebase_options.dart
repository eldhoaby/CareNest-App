// lib/firebase_options.dart
// Generated & merged for project: aal-app-ffaf3
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS has not been configured for aal-app-ffaf3 yet. '
              'Add an iOS app in Firebase Console and re-run FlutterFire CLI.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'macOS has not been configured for aal-app-ffaf3 yet.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Windows has not been configured for aal-app-ffaf3 yet.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux is not supported.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android ─ from google-services.json (aal-app-ffaf3) ──────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDYv73yGzY9uykDC7wtc8d_H6-dWii4yVI',
    appId:             '1:125835803479:android:66ff1b620c0f4bac9e9c12',
    messagingSenderId: '125835803479',
    projectId:         'aal-app-ffaf3',
    storageBucket:     'aal-app-ffaf3.firebasestorage.app',
  );

  // ── Web ─ Replace YOUR_WEB_APP_ID after adding Web app ───────
  // To get this:
  // 1. Go to Firebase Console → aal-app-ffaf3
  // 2. Project Settings → Your Apps → Add App → Web
  // 3. Copy the appId and replace below
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyDYv73yGzY9uykDC7wtc8d_H6-dWii4yVI',
    appId:             'YOUR_WEB_APP_ID', // ⚠️ Replace this!
    messagingSenderId: '125835803479',
    projectId:         'aal-app-ffaf3',
    authDomain:        'aal-app-ffaf3.firebaseapp.com',
    storageBucket:     'aal-app-ffaf3.firebasestorage.app',
  );
}