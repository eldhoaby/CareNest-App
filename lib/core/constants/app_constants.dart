class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────
  static const String appName = 'CareNest';
  static const String appTagline = 'Care That Never Sleeps';

  // ── Firebase Collections ─────────────────────────────────
  static const String usersCollection = 'users';
  static const String alertsCollection = 'alerts';
  static const String notificationsCollection = 'notifications';

  // ── Role-specific collections (Feature #10 — dual-write) ──
  static const String elderlyCollection = 'elderly';
  static const String caregiversCollection = 'caregivers';
  static const String emergencyServicesCollection = 'emergency_services';

  // ── Realtime Database Paths ──────────────────────────────
  static const String sensorPath = 'systems/mmwave_1/mmwave_latest';

  // ── Alert Timing ─────────────────────────────────────────
  /// How often to check sensor data for alert conditions (seconds)
  static const int sensorCheckIntervalSeconds = 5;

  /// Consecutive readings required before triggering a fall alert
  static const int fallConfirmationReadings = 3;

  /// Seconds of confirmed fall posture before firing alert
  static const int fallConfirmationSeconds = 10;

  /// Minutes of no movement before inactivity WARNING state
  static const int inactivityWarningMinutes = 20;

  /// Minutes of no movement before inactivity CRITICAL alert
  static const int inactivityCriticalMinutes = 40;

  /// Seconds of normal condition before resolving an active alert
  static const int alertCooldownSeconds = 15;

  /// Minimum seconds between firing alerts of the same type
  static const int alertDebounceCooldownSeconds = 30;

  /// Legacy — kept for backward compatibility
  static const int inactivityTimeoutMinutes = 30;
  static const int alertCooldownMinutes = 5;

  // ── Invite Code ──────────────────────────────────────────
  static const int inviteCodeLength = 6;
}
