import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course_schedule_entry.dart';
import '../../models/user_role.dart';

class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance; // coverage:ignore-line

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    // coverage:ignore-start
    await _users.doc(uid).set({
      'email': email,
      'role': UserRole.user.value,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // coverage:ignore-end
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  Future<UserRole> getUserRole(String uid) async {
    final data = await getUserProfile(uid);

    if (data == null || data['role'] == null) {
      return UserRole.guest; // safe fallback
    }

    return UserRoleX.fromValue(data['role'] as String);
    // coverage:ignore-end
  }

  Future<void> saveSchedule({
    required String uid,
    required List<CourseScheduleEntry> entries,
  }) async {
    // coverage:ignore-start
    await _users.doc(uid).update({
      'schedule': entries.map((e) => e.toJson()).toList(),
    });
    // coverage:ignore-end
  }

  Future<List<CourseScheduleEntry>> loadSchedule({required String uid}) async {
    // coverage:ignore-start
    final doc = await _users.doc(uid).get();
    final data = doc.data();

    if (data == null || data['schedule'] == null) return [];

    final raw = data['schedule'] as List<dynamic>;
    return raw
        .map((e) => CourseScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    // coverage:ignore-end
  }

}