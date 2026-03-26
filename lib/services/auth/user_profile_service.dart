import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course_schedule_entry.dart';
import '../../models/user_role.dart';

class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required UserRole role,
  }) async {
    await _users.doc(uid).set({
      'email': email,
      'role': role.value, // student | teacher
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserRole> getUserRole(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();

    if (data == null || data['role'] == null) {
      return UserRole.guest; // safe fallback
    }

    return UserRoleX.fromValue(data['role'] as String);
  }

  Future<void> saveSchedule({
    required String uid,
    required List<CourseScheduleEntry> entries,
  }) async {
    await _users.doc(uid).update({
      'schedule': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<CourseScheduleEntry>> loadSchedule({required String uid}) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();

    if (data == null || data['schedule'] == null) return [];

    final raw = data['schedule'] as List<dynamic>;
    return raw
        .map((e) => CourseScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}