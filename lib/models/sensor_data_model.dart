class SensorData {
  final int heartRate;
  final double breathingRate;
  final int spo2;
  final double distance;
  final double temperature;
  final bool presence;
  final bool motion;
  final String posture;
  final bool doorOpen;
  final bool fallDetected;
  final int uptimeMs;

  const SensorData({
    this.heartRate = 0,
    this.breathingRate = 0,
    this.spo2 = 0,
    this.distance = 0,
    this.temperature = 0,
    this.presence = false,
    this.motion = false,
    this.posture = 'unknown',
    this.doorOpen = false,
    this.fallDetected = false,
    this.uptimeMs = 0,
  });

  factory SensorData.fromMap(Map<String, dynamic> map) {
    return SensorData(
      heartRate: (map['heartRate'] ?? map['heart_rate'] ?? 0).toInt(),
      breathingRate:
          (map['breathingRate'] ?? map['breathing_rate'] ?? 0).toDouble(),
      spo2: (map['spo2'] ?? 0).toInt(),
      distance: (map['distance'] ?? 0).toDouble(),
      temperature: (map['temperature'] ?? 0).toDouble(),
      presence: map['presence'] ?? false,
      motion: map['motion'] ?? false,
      posture: map['posture'] ?? 'unknown',
      doorOpen: map['door_open'] ?? map['doorOpen'] ?? false,
      fallDetected: map['fall_detected'] ?? map['fallDetected'] ?? false,
      uptimeMs: (map['uptimeMs'] ?? 0).toInt(),
    );
  }

  /// Determine overall status
  String get statusLabel {
    if (fallDetected || posture == 'fall') return 'EMERGENCY';
    if (!presence) return 'Away';
    if (!motion) return 'Inactive';
    return 'Active';
  }

  /// Whether vitals are in normal range
  bool get vitalsStable {
    final hrOk = heartRate > 0 ? (heartRate >= 50 && heartRate <= 100) : true;
    final spOk = spo2 > 0 ? spo2 >= 94 : true;
    final brOk = breathingRate > 0
        ? (breathingRate >= 10 && breathingRate <= 24)
        : true;
    return hrOk && spOk && brOk;
  }

  /// Whether this is an emergency
  bool get isEmergency => fallDetected || posture == 'fall';

  /// Posture display label
  String get postureLabel {
    switch (posture.toLowerCase()) {
      case 'standing':
        return '🧍 Standing';
      case 'sitting':
        return '🪑 Sitting';
      case 'lying':
        return '🛏 Lying Down';
      case 'fall':
        return '⚠️ Fall Detected';
      default:
        return posture;
    }
  }

  static const SensorData empty = SensorData();
}
