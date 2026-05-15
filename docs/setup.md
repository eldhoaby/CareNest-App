# ⚙️ Local Setup Guide

Follow these instructions to run the CareNest platform locally.

## Prerequisites
- Node.js (v18+)
- Flutter SDK (stable channel)
- Firebase CLI (`npm install -g firebase-tools`)

## 1. Firebase Project Setup
1. Create a new project in the Firebase Console.
2. Enable Firestore, Authentication (Email/Password), and Cloud Messaging.
3. Generate a new service account key and save it as `serviceAccountKey.json`.

## 2. Environment Variables
Create a `.env` file in both the `/backend` and `/frontend` (admin portal) directories based on the `.env.example` templates provided.

## 3. Running the Backend
```bash
cd backend
npm install
npm run dev
```

## 4. Running the Admin Portal
```bash
cd admin-portal
npm install
npm start
```

## 5. Running the Flutter App
```bash
cd mobile-app
flutter pub get
flutter run
```
