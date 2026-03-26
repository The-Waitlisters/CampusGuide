import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'user_profile_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final UserProfileService _profileService;

  // local guest toggle (no Firebase auth for guest)
  bool _guestMode = false;

  AuthService({
    FirebaseAuth? auth,
    UserProfileService? profileService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _profileService = profileService ?? UserProfileService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isGuestMode => _guestMode;

  Future<AppUser> continueAsGuest() async {
    _guestMode = true;
    return AppUser.guest();
  }

  Future<void> signOut() async {
    _guestMode = false;
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  }

  Future<AppUser> signUpStudentOrTeacher({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (role == UserRole.guest) {
      throw ArgumentError('Guest role is not valid for account creation.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    await _profileService.createUserProfile(
      uid: uid,
      email: email,
      role: role,
    );

    _guestMode = false;
    return AppUser(
      uid: uid,
      email: email,
      role: role,
      isGuest: false,
    );
  }

  Future<AppUser> signInStudentOrTeacher({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user!;
    final role = await _profileService.getUserRole(user.uid);

    if (role == UserRole.guest) {
      // protect against broken/missing profile
      throw StateError('User role not found. Please contact support.');
    }

    _guestMode = false;
    return AppUser(
      uid: user.uid,
      email: user.email,
      role: role,
      isGuest: false,
    );
  }

  Future<AppUser?> getCurrentAppUser() async {
    if (_guestMode) return AppUser.guest();

    final user = _auth.currentUser;
    if (user == null) return null;

    final role = await _profileService.getUserRole(user.uid);

    return AppUser(
      uid: user.uid,
      email: user.email,
      role: role,
      isGuest: false,
    );
  }
}