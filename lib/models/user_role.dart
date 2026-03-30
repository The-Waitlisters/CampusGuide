enum UserRole {
  user,
  guest,
}

extension UserRoleX on UserRole {
  String get value => switch (this) {
    UserRole.user => 'user',
    UserRole.guest => 'guest',
  };

  static UserRole fromValue(String value) {
    // Backward compatible with older persisted roles.
    if (value == 'student' || value == 'teacher') {
      return UserRole.user;
    }
    return UserRole.values.firstWhere(
          (r) => r.value == value,
      orElse: () => UserRole.guest,
    );
  }
}