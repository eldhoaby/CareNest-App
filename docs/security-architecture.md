# 🔒 Security Architecture

Security is paramount in healthcare applications. CareNest implements defense-in-depth strategies.

## Data in Transit
All traffic between the Flutter app, React portal, Node.js backend, and Firebase is encrypted using TLS 1.3.

## Authentication
- Handled entirely by Firebase Authentication.
- Caregivers use Email/Password + OAuth.
- Administrators require Multi-Factor Authentication (MFA).

## Database Security (Firestore Rules)
Strict rules ensure users only access authorized data:
```javascript
match /users/{userId} {
  allow read: if request.auth.uid == userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  allow write: if request.auth.uid == userId;
}
```

## Vulnerability Disclosure
If you find a security issue, please review our [SECURITY.md](../SECURITY.md) and report it privately.
