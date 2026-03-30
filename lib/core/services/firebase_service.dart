import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../models/alert_model.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // ─────────────────────────────────────────────
  // CURRENT USER
  // ─────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────

  Future<UserCredential> loginUser({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ─────────────────────────────────────────────
  // LOGIN WITH PHONE LOOKUP
  // ─────────────────────────────────────────────

  Future<String?> getEmailByPhone(String phone) async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data()['email'] as String?;
  }

  // ─────────────────────────────────────────────
  // REGISTER USER
  // ─────────────────────────────────────────────

  Future<UserCredential> registerUser({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set({
      ...profileData,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────
  // GET USER PROFILE (map)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUid == null) return null;
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .get();
    if (!doc.exists) return null;
    return {'uid': doc.id, ...doc.data()!};
  }

  // ─────────────────────────────────────────────
  // GET USER MODEL
  // ─────────────────────────────────────────────

  Future<UserModel?> getUserModel() async {
    if (currentUid == null) return null;
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  // ─────────────────────────────────────────────
  // GET USER MODEL BY UID
  // ─────────────────────────────────────────────

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  // ─────────────────────────────────────────────
  // USER PROFILE STREAM
  // ─────────────────────────────────────────────

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream() {
    if (currentUid == null) {
      throw Exception('User not logged in');
    }
    return _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // UPDATE USER PROFILE
  // ─────────────────────────────────────────────

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (currentUid == null) return;
    await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .update(data);
  }

  // ─────────────────────────────────────────────
  // UPDATE LOCATION
  // ─────────────────────────────────────────────

  Future<void> updateLocation(double lat, double lng) async {
    if (currentUid == null) return;
    await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .update({
      'location': {
        'lat': lat,
        'lng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  // ─────────────────────────────────────────────
  // DISABLE LOCATION SHARING
  // ─────────────────────────────────────────────

  Future<void> disableLocationSharing() async {
    if (currentUid == null) return;
    await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .update({'locationSharing': false});
  }

  // ─────────────────────────────────────────────
  // INVITE CODE SYSTEM
  // ─────────────────────────────────────────────

  /// Generate a random invite code for elderly
  Future<String> generateInviteCode() async {
    if (currentUid == null) throw Exception('Not logged in');

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = String.fromCharCodes(
      Iterable.generate(
        AppConstants.inviteCodeLength,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .update({'inviteCode': code});

    return code;
  }

  /// Look up elderly UID by invite code
  Future<String?> lookupInviteCode(String code) async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .where('role', isEqualTo: 'elderly')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  /// Clear invite code after use
  Future<void> clearInviteCode(String elderlyUid) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(elderlyUid)
        .update({'inviteCode': FieldValue.delete()});
  }

  // ─────────────────────────────────────────────
  // LINKED ELDERLY (for caregiver)
  // ─────────────────────────────────────────────

  Future<UserModel?> getLinkedElderly(String elderlyUid) async {
    return getUserById(elderlyUid);
  }

  /// Look up elderly by phone number
  Future<String?> lookupElderlyByPhone(String phone) async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('phone', isEqualTo: phone)
        .where('role', isEqualTo: 'elderly')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  // ─────────────────────────────────────────────
  // SETUP / ONBOARDING
  // ─────────────────────────────────────────────

  /// Save a setup step's data to Firestore
  Future<void> saveSetupStep(Map<String, dynamic> data) async {
    if (currentUid == null) return;
    await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .update(data);
  }

  /// Mark profile as complete
  Future<void> completeSetup() async {
    if (currentUid == null) return;
    await _db
        .collection(AppConstants.usersCollection)
        .doc(currentUid)
        .update({'profileComplete': true});
  }

  /// Check if profile setup is complete
  Future<bool> isProfileComplete() async {
    final profile = await getUserProfile();
    return profile?['profileComplete'] == true;
  }

  // ─────────────────────────────────────────────
  // ALERTS
  // ─────────────────────────────────────────────

  /// Create a new alert
  Future<void> createAlert({
    required String userId,
    String? elderlyName,
    required AlertType type,
    required AlertPriority priority,
    required String description,
  }) async {
    final alertData = AlertModel(
      id: '',
      userId: userId,
      elderlyName: elderlyName,
      type: type,
      priority: priority,
      description: description,
      status: AlertStatus.active,
    );

    await _db
        .collection(AppConstants.alertsCollection)
        .add(alertData.toMap());
  }

  /// Stream alerts for a specific elderly user
  Stream<QuerySnapshot> alertsStream(String elderlyUid) {
    return _db
        .collection(AppConstants.alertsCollection)
        .where('userId', isEqualTo: elderlyUid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Stream ALL active high-priority alerts (for emergency services)
  Stream<QuerySnapshot> activeEmergencyAlerts() {
    return _db
        .collection(AppConstants.alertsCollection)
        .where('priority', isEqualTo: 'high')
        .where('status', whereIn: ['active', 'responded'])
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Stream ALL alerts (for emergency history)
  Stream<QuerySnapshot> allAlertsStream() {
    return _db
        .collection(AppConstants.alertsCollection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Respond to an alert
  Future<void> respondToAlert(String alertId, String responderUid) async {
    await _db
        .collection(AppConstants.alertsCollection)
        .doc(alertId)
        .update({
      'status': 'responded',
      'respondedBy': responderUid,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resolve an alert
  Future<void> resolveAlert(String alertId) async {
    await _db
        .collection(AppConstants.alertsCollection)
        .doc(alertId)
        .update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────
  // REALTIME DATABASE SENSOR STREAM
  // ─────────────────────────────────────────────

  Stream<DatabaseEvent> sensorStream() {
    final ref = _rtdb.ref(AppConstants.sensorPath);
    return ref.onValue;
  }

  // ─────────────────────────────────────────────
  // FCM
  // ─────────────────────────────────────────────

  Future<void> initFCM() async {
    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();

      if (token != null && currentUser != null) {
        await _db
            .collection(AppConstants.usersCollection)
            .doc(currentUser!.uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  /// Subscribe to role-based topic
  Future<void> subscribeToRoleTopic(String role) async {
    try {
      await _messaging.subscribeToTopic('alerts_$role');
      debugPrint('Subscribed to alerts_$role');
    } catch (e) {
      debugPrint('Topic subscribe error: $e');
    }
  }
}
