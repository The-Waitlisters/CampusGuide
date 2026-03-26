import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/screens/auth/register_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';
import 'package:proj/models/user_role.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

void main() {

  setUpAll(() {
    registerFallbackValue(UserRole.student);
  });

  late AuthService authService;
  late MockUserProfileService mockProfile;

  setUp(() {
    final mockAuth = MockFirebaseAuth();
    mockProfile = MockUserProfileService();

    when(() => mockProfile.createUserProfile(
      uid: any(named: 'uid'),
      email: any(named: 'email'),
      role: any(named: 'role'),
    )).thenAnswer((_) async {});
    when(() => mockProfile.getUserRole(any())).thenAnswer((_) async => throw Exception('not used'));

    authService = AuthService(
      auth: mockAuth,
      profileService: mockProfile,
    );
  });

  testWidgets('LoginScreen renders controls', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders controls', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: authService)));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Account type'), findsOneWidget);
    expect(find.text('Student'), findsWidgets);
    expect(find.text('Teacher'), findsWidgets);
  });
}