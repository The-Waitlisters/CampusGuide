import 'package:cloud_firestore/cloud_firestore.dart';
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
}