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

  // ── New fields from actual RTDB ──────────────────────────
  final bool abnormalBreathing;
  final String abnormalReason;
  final int movementRaw; // raw movement value from sensor (0 = still)

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
    this.abnormalBreathing = false,
    this.abnormalReason = '',
    this.movementRaw = 0,
  });

  /// Parse the actual Firebase RTDB structure at systems/mmwave_1/mmwave_latest
  ///
  /// Real fields:
  ///   heart_rate (int), movement (int 0/1+), presence (bool),
  ///   respiration (int), abnormal_breathing (bool),
  ///   abnormal_reason (string), timestamp (int)
  ///
  /// Fields NOT in RTDB use sensible defaults when sensor is connected:
  ///   spo2 → 98, temperature → 36.5, posture → derived from presence+movement,
  ///   doorOpen → false, fallDetected → false
  factory SensorData.fromMap(Map<String, dynamic> map) {
    // ── Read raw RTDB values ───────────────────────────────
    final rawHeartRate =
        (map['heart_rate'] ?? map['heartRate'] ?? 0).toInt();
    final rawMovement =
        (map['movement'] ?? 0).toInt();
    final rawPresence = map['presence'] ?? false;
    final rawRespiration =
        (map['respiration'] ?? map['breathingRate'] ?? map['breathing_rate'] ?? 0)
            .toDouble();
    final rawAbnormalBreathing = map['abnormal_breathing'] ?? false;
    final rawAbnormalReason =
        (map['abnormal_reason'] ?? '').toString();
    final rawTimestamp = (map['timestamp'] ?? map['uptimeMs'] ?? 0).toInt();

    // ── Derive motion (bool) from movement (int) ──────────
    final isMoving = rawMovement > 0;

    // ── Derive posture from presence + movement ───────────
    // (Only if no explicit posture field exists in the data)
    String derivedPosture;
    if (map.containsKey('posture')) {
      derivedPosture = map['posture'] ?? 'unknown';
    } else if (!rawPresence) {
      derivedPosture = 'unknown';
    } else if (isMoving) {
      derivedPosture = 'standing';
    } else {
      // Present but not moving → likely lying/resting
      derivedPosture = 'lying';
    }

    // ── Static defaults for sensors not in RTDB ───────────
    // When sensor is connected (presence data exists), show normal defaults
    // so the UI isn't showing 0 for everything
    final defaultSpo2 = rawPresence ? 98 : 0;
    final defaultTemp = rawPresence ? 36.5 : 0.0;

    return SensorData(
      heartRate: rawHeartRate,
      breathingRate: rawRespiration,
      spo2: (map['spo2'] ?? defaultSpo2).toInt(),
      distance: (map['distance'] ?? 0).toDouble(),
      temperature: (map['temperature'] ?? defaultTemp).toDouble(),
      presence: rawPresence,
      motion: isMoving,
      posture: derivedPosture,
      doorOpen: map['door_open'] ?? map['doorOpen'] ?? false,
      fallDetected: map['fall_detected'] ?? map['fallDetected'] ?? false,
      uptimeMs: rawTimestamp,
      abnormalBreathing: rawAbnormalBreathing,
      abnormalReason: rawAbnormalReason,
      movementRaw: rawMovement,
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
    final breathingOk = !abnormalBreathing;
    return hrOk && spOk && brOk && breathingOk;
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

  /// Position label (for Live Status card – Standing / Lying)
  String get positionLabel {
    final p = posture.toLowerCase();
    if (p == 'standing') return 'Standing';
    if (p == 'lying') return 'Lying';
    if (p == 'sitting') return 'Sitting';
    if (p == 'fall') return 'Fallen';
    return 'Unknown';
  }

  /// Activity label derived from motion + posture
  String get activityLabel {
    if (fallDetected || posture == 'fall') return 'Fall Detected';
    if (!presence) return 'Not Present';
    if (posture.toLowerCase() == 'lying' && !motion) return 'Sleeping';
    if (motion) return 'Walking';
    if (posture.toLowerCase() == 'sitting') return 'Sitting';
    return 'Resting';
  }

  /// Whether the person appears to be sleeping
  bool get isSleeping =>
      presence &&
      !motion &&
      posture.toLowerCase() == 'lying';

  /// Breathing status label for display
  String get breathingLabel {
    if (!presence) return 'No Data';
    if (abnormalBreathing) {
      if (abnormalReason.isNotEmpty) {
        // Capitalize first letter of reason
        return abnormalReason[0].toUpperCase() + abnormalReason.substring(1);
      }
      return 'Abnormal';
    }
    return 'Normal';
  }

  /// Smart AI-like status message for the insight card
  String get smartStatusMessage {
    if (isEmergency) return 'Fall detected – immediate attention required';
    if (abnormalBreathing) {
      final reason = abnormalReason.isNotEmpty ? ' ($abnormalReason)' : '';
      return 'Abnormal breathing detected$reason – monitoring closely';
    }
    if (!presence) return 'Elderly is currently not in sensor range';
    if (isSleeping) return 'Elderly is sleeping peacefully';
    if (!motion) return 'Elderly is resting and stable';
    return 'Elderly is active and safe';
  }

  /// Presence label for display
  String get presenceLabel => presence ? 'Present' : 'Not Present';

  /// Door label for display
  String get doorLabel => doorOpen ? 'Open' : 'Closed';

  static const SensorData empty = SensorData();
}
