import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

void main() {

  late MockFirebaseAuth mockAuth;
  late MockUserProfileService mockProfile;
  late AuthService authService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockProfile = MockUserProfileService();

    authService = AuthService(
      auth: mockAuth,
      profileService: mockProfile,
    );
  });

  group('AuthService', () {
    test('continueAsGuest sets guest mode', () async {
      final user = await authService.continueAsGuest();
      expect(authService.isGuestMode, true);
      expect(user.isGuest, true);
      expect(user.role, UserRole.guest);
    });

    test('signOut clears guest mode', () async {
      await authService.continueAsGuest();
      await authService.signOut();
      expect(authService.isGuestMode, false);
    });

    test('signup creates profile with first/last name', () async {
      when(() => mockProfile.createUserProfile(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      )).thenAnswer((_) async {});

      final user = await authService.signUp(
        email: 'user@test.com',
        password: '123456',
        firstName: 'Brett',
        lastName: 'Lee',
      );

      expect(user.role, UserRole.user);
      expect(user.firstName, 'Brett');
      expect(user.lastName, 'Lee');
      verify(() => mockProfile.createUserProfile(
        uid: user.uid!,
        email: 'user@test.com',
        firstName: 'Brett',
        lastName: 'Lee',
      )).called(1);
    });

    test('signIn returns authenticated user with profile names', () async {
      // create user in mock auth first
      await mockAuth.createUserWithEmailAndPassword(
        email: 'person@test.com',
        password: 'abcdef',
      );
      await mockAuth.signOut();

      when(() => mockProfile.getUserProfile(any())).thenAnswer(
            (_) async => {
          'role': 'user',
          'firstName': 'Taylor',
          'lastName': 'Kim',
        },
      );

      final user = await authService.signIn(
        email: 'person@test.com',
        password: 'abcdef',
      );

      expect(user.role, UserRole.user);
      expect(user.firstName, 'Taylor');
      expect(user.isGuest, false);
    });

    test('signIn throws when profile has no valid role', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'broken@test.com',
        password: 'abcdef',
      );
      await mockAuth.signOut();

      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => {
        'firstName': 'Broken',
      });

      expect(
            () => authService.signIn(
          email: 'broken@test.com',
          password: 'abcdef',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('getCurrentAppUser returns null when no signed-in user', () async {
      final appUser = await authService.getCurrentAppUser();
      expect(appUser, isNull);
    });

    test('getCurrentAppUser returns guest when guest mode is enabled', () async {
      await authService.continueAsGuest();
      final appUser = await authService.getCurrentAppUser();
      expect(appUser, isNotNull);
      expect(appUser!.isGuest, isTrue);
      expect(appUser.role, UserRole.guest);
    });

    test('getCurrentAppUser returns names and mapped role for signed-in user', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'legacy@test.com',
        password: 'abcdef',
      );

      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => {
        'role': 'student',
        'firstName': 'Legacy',
        'lastName': 'User',
      });

      final appUser = await authService.getCurrentAppUser();

      expect(appUser, isNotNull);
      expect(appUser!.role, UserRole.user);
      expect(appUser.firstName, 'Legacy');
      expect(appUser.lastName, 'User');
    });
  });
}