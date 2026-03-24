enum UserRole {
  student,
  teacher,
  guest,
}

extension UserRoleX on UserRole {
  String get value => switch (this) {
    UserRole.student => 'student',
    UserRole.teacher => 'teacher',
    UserRole.guest => 'guest',
  };

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
          (r) => r.value == value,
      orElse: () => UserRole.guest,
    );
  }
}