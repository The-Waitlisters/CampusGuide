import 'user_role.dart';

class AppUser {
  final String? uid;       // null for guest
  final String? email;     // null for guest
  final UserRole role;
  final String? firstName;
  final String? lastName;
  final bool isGuest;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    required this.isGuest,
  });

  factory AppUser.guest() => const AppUser(
    uid: null,
    email: null,
    role: UserRole.guest,
    firstName: null,
    lastName: null,
    isGuest: true,
  );
}