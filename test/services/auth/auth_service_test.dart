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

    test('signOut signs out firebase user when authenticated user exists', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'signedin@test.com',
        password: '123456',
      );

      expect(mockAuth.currentUser, isNotNull);
      await authService.signOut();
      expect(mockAuth.currentUser, isNull);
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

    test('signIn returns user role with profile names', () async {
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

    test('signIn throws StateError when profile is null', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'noprofile@test.com',
        password: 'abcdef',
      );
      await mockAuth.signOut();

      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => null);

      expect(
            () => authService.signIn(
          email: 'noprofile@test.com',
          password: 'abcdef',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('getCurrentAppUser returns guest role when signed-in profile is null', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'nullprofile@test.com',
        password: 'abcdef',
      );

      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => null);

      final appUser = await authService.getCurrentAppUser();

      expect(appUser, isNotNull);
      expect(appUser!.role, UserRole.guest);
    });
  });

  test('signOut signs out of Firebase when a user is currently signed in', () async {
    final signedInAuth = MockFirebaseAuth(signedIn: true);
    final service = AuthService(auth: signedInAuth, profileService: mockProfile);

    expect(signedInAuth.currentUser, isNotNull);

    await service.signOut();

    expect(service.isGuestMode, false);
    expect(signedInAuth.currentUser, isNull);
  });

  test('signIn throws StateError when profile returns guest role', () async {
    await mockAuth.createUserWithEmailAndPassword(
      email: 'broken@test.com',
      password: 'abcdef',
    );
    await mockAuth.signOut();

    when(() => mockProfile.getUserRole(any())).thenAnswer((_) async => UserRole.guest);

    expect(
          () => authService.signInStudentOrTeacher(
        email: 'broken@test.com',
        password: 'abcdef',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('getCurrentAppUser returns guest AppUser when in guest mode', () async {
    await authService.continueAsGuest();
    final user = await authService.getCurrentAppUser();
    expect(user?.isGuest, isTrue);
    expect(user?.role, UserRole.guest);
  });

  test('getCurrentAppUser returns null when no user is signed in', () async {
    final user = await authService.getCurrentAppUser();
    expect(user, isNull);
  });

  test('getCurrentAppUser returns AppUser with role when signed in', () async {
    final signedInAuth = MockFirebaseAuth(signedIn: true);
    when(() => mockProfile.getUserRole(any())).thenAnswer((_) async => UserRole.student);
    final service = AuthService(auth: signedInAuth, profileService: mockProfile);

    final user = await service.getCurrentAppUser();

    expect(user?.role, UserRole.student);
    expect(user?.isGuest, isFalse);
  });
});
}