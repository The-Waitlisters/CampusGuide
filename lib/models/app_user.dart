import 'user_role.dart';

class AppUser {
  final String? uid;       // null for guest
  final String? email;     // null for guest
  final UserRole role;
  final bool isGuest;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.isGuest,
  });

  factory AppUser.guest() => const AppUser(
    uid: null,
    email: null,
    role: UserRole.guest,
    isGuest: true,
  );
}