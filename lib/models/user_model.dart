import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { elderly, caregiver, emergency }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool profileComplete;

  // ── Common ───────────────────────────
  final String? fcmToken;
  final DateTime? createdAt;

  // ── Elderly Fields ───────────────────
  final String? dateOfBirth;
  final String? gender;
  final String? medicalConditions;
  final String? mobilityStatus;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? bloodGroup;
  final String? inviteCode;
  final String? caregiverPhone;
  final bool locationSharing;

  // ── Caregiver Fields ─────────────────
  final String? linkedElderlyUid;
  final String? relationship;

  // ── Emergency Fields ─────────────────
  final String? organizationName;
  final String? staffName;
  final String? availability; // '24/7' or custom
  final bool ambulanceAvailable;
  final String? emergencyTypes;

  // ── Location ─────────────────────────
  final double? lat;
  final double? lng;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileComplete = false,
    this.fcmToken,
    this.createdAt,
    this.dateOfBirth,
    this.gender,
    this.medicalConditions,
    this.mobilityStatus,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.bloodGroup,
    this.inviteCode,
    this.caregiverPhone,
    this.locationSharing = false,
    this.linkedElderlyUid,
    this.relationship,
    this.organizationName,
    this.staffName,
    this.availability,
    this.ambulanceAvailable = false,
    this.emergencyTypes,
    this.lat,
    this.lng,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: _parseRole(map['role'] ?? 'elderly'),
      profileComplete: map['profileComplete'] ?? false,
      fcmToken: map['fcmToken'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      dateOfBirth: map['dateOfBirth'],
      gender: map['gender'],
      medicalConditions: map['medicalConditions'],
      mobilityStatus: map['mobilityStatus'],
      emergencyContactName: map['emergencyContactName'],
      emergencyContactPhone: map['emergencyContactPhone'],
      bloodGroup: map['bloodGroup'],
      inviteCode: map['inviteCode'],
      caregiverPhone: map['caregiverPhone'],
      locationSharing: map['locationSharing'] ?? false,
      linkedElderlyUid: map['linkedElderlyUid'],
      relationship: map['relationship'],
      organizationName: map['organizationName'],
      staffName: map['staffName'],
      availability: map['availability'],
      ambulanceAvailable: map['ambulanceAvailable'] ?? false,
      emergencyTypes: map['emergencyTypes'],
      lat: (map['location'] as Map?)?['lat']?.toDouble(),
      lng: (map['location'] as Map?)?['lng']?.toDouble(),
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'profileComplete': profileComplete,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'caregiver':
        return UserRole.caregiver;
      case 'emergency':
        return UserRole.emergency;
      default:
        return UserRole.elderly;
    }
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.elderly:
        return 'Elderly';
      case UserRole.caregiver:
        return 'Caregiver';
      case UserRole.emergency:
        return 'Emergency Services';
    }
  }
}
