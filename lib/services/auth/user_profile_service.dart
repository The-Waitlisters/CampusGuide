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
    required String firstName,
    required String lastName,
  }) async {
    await _users.doc(uid).set({
      'email': email,
      'role': UserRole.user.value,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
  }
}