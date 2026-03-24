import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('contains student, teacher, guest', () {
      expect(UserRole.values, contains(UserRole.student));
      expect(UserRole.values, contains(UserRole.teacher));
      expect(UserRole.values, contains(UserRole.guest));
      expect(UserRole.values.length, 3);
    });

    test('string values are correct', () {
      expect(UserRole.student.value, 'student');
      expect(UserRole.teacher.value, 'teacher');
      expect(UserRole.guest.value, 'guest');
    });

    test('fromValue maps correctly', () {
      expect(UserRoleX.fromValue('student'), UserRole.student);
      expect(UserRoleX.fromValue('teacher'), UserRole.teacher);
      expect(UserRoleX.fromValue('guest'), UserRole.guest);
    });

    test('fromValue falls back to guest for unknown', () {
      expect(UserRoleX.fromValue('unknown-role'), UserRole.guest);
    });
  });
}