import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('contains user-authenticated and guest', () {
      expect(UserRole.values, contains(UserRole.user));
      expect(UserRole.values, contains(UserRole.guest));
      expect(UserRole.values.length, 2);
    });

    test('string values are correct', () {
      expect(UserRole.user.value, 'user');
      expect(UserRole.guest.value, 'guest');
    });

    test('fromValue maps correctly', () {
      expect(UserRoleX.fromValue('user'), UserRole.user);
      expect(UserRoleX.fromValue('guest'), UserRole.guest);
    });

    test('fromValue maps legacy values to user', () {
      expect(UserRoleX.fromValue('user'), UserRole.user);
    });


    test('fromValue falls back to guest for unknown', () {
      expect(UserRoleX.fromValue('unknown-role'), UserRole.guest);
    });
  });
}