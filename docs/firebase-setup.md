# 🔥 Firebase Setup Guide

CareNest heavily relies on Firebase for real-time capabilities and identity management.

## 1. Authentication
Go to the Firebase Console -> Authentication -> Sign-in method.
- Enable **Email/Password**.
- Enable **Google Auth** (Optional for Caregivers).

## 2. Firestore Database
Go to Firestore Database and create a database in production mode.
- Set up the collections as described in the [Database Schema](database-schema.md).
- Deploy the security rules from `firestore.rules`.

## 3. Firebase Cloud Messaging (FCM)
FCM is required to send push notifications to the Flutter app.
- Download the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from the project settings.
- Place them in the respective `android/app/` and `ios/Runner/` directories.
