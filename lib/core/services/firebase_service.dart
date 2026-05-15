import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStreamById(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
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

  /// Look up caregiver by phone number
  Future<String?> lookupCaregiverByPhone(String phone) async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('phone', isEqualTo: phone)
        .where('role', isEqualTo: 'caregiver')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  /// Send a link request
  Future<void> sendLinkRequest({
    required String fromUid,
    required String toUid,
    required String fromRole,
  }) async {
    await _db.collection('link_requests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromRole': fromRole,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Auto-link using invite code
  Future<bool> tryAutoLinkWithCode(String code, String currentRole) async {
    if (currentUid == null) return false;
    
    // Caregiver entering Elderly code
    if (currentRole == 'caregiver') {
      final elderlyUid = await lookupInviteCode(code);
      if (elderlyUid != null) {
        await _db.collection(AppConstants.usersCollection).doc(currentUid).update({
          'linkedElderlyUid': elderlyUid
        });
        await clearInviteCode(elderlyUid);
        return true;
      }
    }
    // Elderly entering Caregiver code (if supported)
    return false;
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

  /// Create a new alert and return optimistic AlertModel
  Future<AlertModel> createAlert({
    required String userId,
    String? elderlyName,
    required String type,
    required AlertPriority priority,
    required String description,
  }) async {
    // Fetch address for emergency response profiling
    String? finalAddress;
    try {
      final doc = await _db.collection(AppConstants.usersCollection).doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['address'] != null) {
          finalAddress = data['address'];
        }
      }
    } catch (_) {}

    final alertData = AlertModel(
      id: '',
      elderlyId: userId,
      elderlyName: elderlyName,
      address: finalAddress,
      type: type,
      priority: priority,
      description: description,
      status: AlertStatus.active,
    );

    final docRef = await _db
        .collection(AppConstants.alertsCollection)
        .add(alertData.toMap());
        
    return alertData.copyWith(
      id: docRef.id,
      timestamp: DateTime.now(),
    );
  }

  /// Stream alerts for a specific elderly user (DEPRECATED, use alertsForElderliesStream)
  Stream<QuerySnapshot> alertsStream(String elderlyUid, {DateTime? date}) {
    return alertsForElderliesStream([elderlyUid], date: date);
  }

  /// Stream alerts for MULTIPLE elderly users
  ///
  /// NOTE: Date filtering is done client-side because Firestore cannot combine
  /// Filter.or() with inequality range filters on a different field (timestamp).
  /// Combining them causes the query to silently fail / never emit.
  Stream<QuerySnapshot> alertsForElderliesStream(List<String> elderlyUids, {DateTime? date}) {
    if (elderlyUids.isEmpty) {
      return const Stream.empty();
    }

    // When querying for a single user (most common), use Filter.or to match
    // alerts stored under EITHER 'elderlyId' or 'userId' field — external
    // sensor systems may write to either field.
    if (elderlyUids.length == 1) {
      final uid = elderlyUids.first;

      // NOTE: date filtering with Filter.or + inequality is not supported
      // by Firestore, so date filtering is done client-side (same as multi-user).
      final query = _db
          .collection(AppConstants.alertsCollection)
          .where(
            Filter.or(
              Filter('elderlyId', isEqualTo: uid),
              Filter('userId', isEqualTo: uid),
            ),
          )
          .orderBy('timestamp', descending: true)
          .limit(50);

      return query.snapshots();
    }

    // For multiple elderly UIDs, use Filter.or without date range
    // (date filtering will be done client-side)
    final query = _db
        .collection(AppConstants.alertsCollection)
        .where(
          Filter.or(
            Filter('elderlyId', whereIn: elderlyUids),
            Filter('userId', whereIn: elderlyUids),
          ),
        )
        .orderBy('timestamp', descending: true)
        .limit(50);

    return query.snapshots();
  }

  /// FETCH alerts via .get() instead of a real-time stream
  Future<QuerySnapshot> getAlertsForElderlies(List<String> elderlyUids, {DateTime? date, int limit = 50}) {
    if (elderlyUids.isEmpty) {
      throw Exception("No elderly UIDs provided");
    }

    if (elderlyUids.length == 1) {
      final uid = elderlyUids.first;

      // Use Filter.or to match both elderlyId and userId fields.
      // Date filtering is done client-side when using Filter.or.
      final query = _db
          .collection(AppConstants.alertsCollection)
          .where(
            Filter.or(
              Filter('elderlyId', isEqualTo: uid),
              Filter('userId', isEqualTo: uid),
            ),
          )
          .orderBy('timestamp', descending: true)
          .limit(limit);

      return query.get();
    }

    final query = _db
        .collection(AppConstants.alertsCollection)
        .where(
          Filter.or(
            Filter('elderlyId', whereIn: elderlyUids),
            Filter('userId', whereIn: elderlyUids),
          ),
        )
        .orderBy('timestamp', descending: true)
        .limit(limit);

    return query.get();
  }

  /// Stream ALL active high-priority alerts (for legacy emergency systems)
  Stream<QuerySnapshot> activeEmergencyAlerts() {
    return _db
        .collection(AppConstants.alertsCollection)
        .where('priority', isEqualTo: 'high')
        .where('status', whereIn: ['active', 'responded'])
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Global Active Alerts Stream (for updated Emergency Dashboard)
  Stream<QuerySnapshot> globalActiveAlertsStream() {
    return _db
        .collection(AppConstants.alertsCollection)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Global Resolved Alerts Stream (for Emergency History Tab)
  /// NOTE: No orderBy to avoid composite index requirement.
  /// Sorting is done client-side in the History tab.
  Stream<QuerySnapshot> globalResolvedAlertsStream() {
    return _db
        .collection(AppConstants.alertsCollection)
        .where('status', isEqualTo: 'resolved')
        .limit(100)
        .snapshots();
  }

  /// Stream ALL alerts (for elderly/caregiver local history)
  Stream<QuerySnapshot> allAlertsStream() {
    return _db
        .collection(AppConstants.alertsCollection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Stream ALL notifications (from the notifications collection)
  Stream<QuerySnapshot> allNotificationsStream() {
    return _db
        .collection(AppConstants.notificationsCollection)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Fetch ALL recent alerts without user filtering.
  /// Use this when you need to capture alerts from external sensor systems
  /// that may not set elderlyId/userId to match Firebase Auth UIDs.
  /// Callers should apply client-side filtering for the target user(s).
  Future<QuerySnapshot> getRecentAlerts({int limit = 200}) {
    return _db
        .collection(AppConstants.alertsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
  }

  /// Fetch ALL recent notifications without user filtering.
  Future<QuerySnapshot> getRecentNotifications({int limit = 200}) {
    return _db
        .collection(AppConstants.notificationsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
  }

  /// Stream activity logs for elderly users
  Stream<QuerySnapshot> activitiesStream(List<String> elderlyUids) {
    if (elderlyUids.isEmpty) return const Stream.empty();
    return _db
        .collection('activities')
        // OR simple mode: .where('elderlyId', isEqualTo: elderlyUids.first)
        .where('elderlyId', whereIn: elderlyUids)
        .limit(50)
        .snapshots();
  }

  /// Respond to an alert
  Future<void> respondToAlert(String alertId, String responderUid) async {
    await _db
        .collection(AppConstants.alertsCollection)
        .doc(alertId)
        .set({
      'status': 'responded',
      'respondedBy': responderUid,
      'respondedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Resolve an alert
  Future<void> resolveAlert(String alertId, {String? resolverUid}) async {
    final uid = resolverUid ?? currentUid;
    await _db
        .collection(AppConstants.alertsCollection)
        .doc(alertId)
        .set({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'resolvedBy': uid,
    }, SetOptions(merge: true));
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

  // ─────────────────────────────────────────────
  // PROFILE PHOTO — Feature #7
  // ─────────────────────────────────────────────

  /// Upload profile photo to Firebase Storage and save URL in Firestore
  Future<String> uploadProfilePhoto(File imageFile) async {
    if (currentUid == null) throw Exception('Not logged in');

    final ref = _storage.ref().child('profile_photos/$currentUid.jpg');
    final uploadTask = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await uploadTask.ref.getDownloadURL();

    // Save URL to user profile
    await updateUserProfile({'profilePhotoUrl': url});

    return url;
  }

  /// Get profile photo URL from Firestore
  Future<String?> getProfilePhotoUrl() async {
    final profile = await getUserProfile();
    return profile?['profilePhotoUrl'] as String?;
  }

  // ─────────────────────────────────────────────
  // DUAL-WRITE COLLECTIONS — Feature #10
  //
  // Hybrid approach: writes to both users/{uid}
  // AND the role-specific collection.
  // Existing code continues reading from 'users'.
  // ─────────────────────────────────────────────

  /// Get the Firestore collection name for a role
  String _roleCollection(String role) {
    switch (role.toLowerCase()) {
      case 'caregiver':
        return AppConstants.caregiversCollection;
      case 'emergency':
        return AppConstants.emergencyServicesCollection;
      default:
        return AppConstants.elderlyCollection;
    }
  }

  /// Register user with dual-write: users + role-specific collection
  Future<UserCredential> registerUserByRole({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final fullData = {
      ...profileData,
      'uid': uid,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Write to main users collection
    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(fullData);

    // Write to role-specific collection
    await _db
        .collection(_roleCollection(role))
        .doc(uid)
        .set(fullData);

    return credential;
  }

  /// Query all elderly users (from role-specific collection)
  Future<List<UserModel>> getElderlyUsers() async {
    final snapshot = await _db
        .collection(AppConstants.elderlyCollection)
        .get();
    return snapshot.docs.map((d) => UserModel.fromDoc(d)).toList();
  }

  /// Query all caregivers (from role-specific collection)
  Future<List<UserModel>> getCaregivers() async {
    final snapshot = await _db
        .collection(AppConstants.caregiversCollection)
        .get();
    return snapshot.docs.map((d) => UserModel.fromDoc(d)).toList();
  }

  /// Sync existing user to role-specific collection (migration helper)
  Future<void> syncUserToRoleCollection() async {
    if (currentUid == null) return;
    final profile = await getUserProfile();
    if (profile == null) return;

    final role = profile['role'] as String? ?? 'elderly';
    final collection = _roleCollection(role);

    // Write/update to role collection
    await _db.collection(collection).doc(currentUid).set(
      profile,
      SetOptions(merge: true),
    );
  }
}
