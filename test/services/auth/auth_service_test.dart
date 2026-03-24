import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

void main() {

  setUpAll(() {
    registerFallbackValue(UserRole.student);
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

    test('signup rejects guest role', () async {
      expect(
            () => authService.signUpStudentOrTeacher(
          email: 'x@y.com',
          password: '123456',
          role: UserRole.guest,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('signup student calls profile createUserProfile', () async {
      when(() => mockProfile.createUserProfile(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      )).thenAnswer((_) async {});

      final user = await authService.signUpStudentOrTeacher(
        email: 'student@test.com',
        password: '123456',
        role: UserRole.student,
      );

      expect(user.role, UserRole.student);
      verify(() => mockProfile.createUserProfile(
        uid: user.uid!,
        email: 'student@test.com',
        role: UserRole.student,
      )).called(1);
    });

    test('signIn returns role from profile service', () async {
      // create user in mock auth first
      await mockAuth.createUserWithEmailAndPassword(
        email: 'teacher@test.com',
        password: 'abcdef',
      );
      await mockAuth.signOut();

      // For createUserProfile (named params)
      when(() => mockProfile.createUserProfile(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      )).thenAnswer((_) async {});


      when(() => mockProfile.getUserRole(any())).thenAnswer((_) async => UserRole.teacher);

      final user = await authService.signInStudentOrTeacher(
        email: 'teacher@test.com',
        password: 'abcdef',
      );

      expect(user.role, UserRole.teacher);
      expect(user.isGuest, false);
    });
  });
}