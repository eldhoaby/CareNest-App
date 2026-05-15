# 🚀 Deployment Guide

CareNest is deployed using modern cloud platforms.

## Mobile Application
The Flutter application is built and distributed via standard CI pipelines.
- **Android:** Generates an `.aab` for the Google Play Store.
- **iOS:** Generates an `.ipa` for TestFlight / App Store.

## Backend (Render)
The Node.js backend is automatically deployed to Render on pushes to the `main` branch. Ensure the following environment variables are set in the Render dashboard:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_PRIVATE_KEY`
- `FIREBASE_CLIENT_EMAIL`

## Admin Portal (Vercel)
The React dashboard is hosted on Vercel. Connect your GitHub repository to Vercel and it will automatically deploy the frontend. Ensure all API URL environment variables point to the live Render backend.
