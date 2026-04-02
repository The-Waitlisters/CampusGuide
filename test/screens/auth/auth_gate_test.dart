import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

void main() {

  setUpAll(() {
    registerFallbackValue(UserRole.user);
  });

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

    test('signup calls profile createUserProfile', () async {
      when(() => mockProfile.createUserProfile(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      )).thenAnswer((_) async {});

      final user = await authService.signUp(
        email: 'x@y.com',
        password: '123456',
        firstName: 'Cool',
        lastName: 'Man',
      );

      expect(user.role, UserRole.user);
      verify(() => mockProfile.createUserProfile(
        uid: user.uid!,
        email: 'x@y.com',
        firstName: 'Cool',
        lastName: 'Man',
      )).called(1);
    });

    test('signIn returns role from profile service', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'user@test.com',
        password: 'abcdef',
      );
      await mockAuth.signOut();

      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => {'role': 'user', 'firstName': 'Taylor', 'lastName': 'Kim'});

      final user = await authService.signIn(
        email: 'user@test.com',
        password: 'abcdef',
      );

      expect(user.role, UserRole.user);
      expect(user.isGuest, false);
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

      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => {'role': 'guest', 'firstName': 'Broken', 'lastName': 'User'});

      expect(
            () => authService.signIn(
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
      when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => {'role': 'user', 'firstName': 'Test', 'lastName': 'User'});
      final service = AuthService(auth: signedInAuth, profileService: mockProfile);

      final user = await service.getCurrentAppUser();

      expect(user?.role, UserRole.user);
      expect(user?.isGuest, isFalse);
    });
  });
}