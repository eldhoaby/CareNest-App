class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────
  static const String appName = 'SmartNest';
  static const String appTagline = 'Care That Never Sleeps';

  // ── Firebase Collections ─────────────────────────────────
  static const String usersCollection = 'users';
  static const String alertsCollection = 'alerts';

  // ── Realtime Database Paths ──────────────────────────────
  static const String sensorPath = 'mmwave/sensor1';

  // ── Alert Timing ─────────────────────────────────────────
  static const int inactivityTimeoutMinutes = 30;
  static const int alertCooldownMinutes = 5;

  // ── Invite Code ──────────────────────────────────────────
  static const int inviteCodeLength = 6;
}
