import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/app_user.dart';
import 'package:proj/models/user_role.dart';

void main() {
  group('AppUser', () {
    test('guest factory creates guest user', () {
      final guest = AppUser.guest();

      expect(guest.uid, isNull);
      expect(guest.email, isNull);
      expect(guest.role, UserRole.guest);
      expect(guest.isGuest, isTrue);
    });
  });
}