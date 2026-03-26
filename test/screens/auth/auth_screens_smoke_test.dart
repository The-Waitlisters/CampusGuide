import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/models/app_user.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/screens/auth/register_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';
import 'package:proj/models/user_role.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

class MockAuthService extends Mock implements AuthService {}

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

  setUpAll(() {
    registerFallbackValue(UserRole.student);
  });

  testWidgets('LoginScreen renders controls', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('LoginScreen shows "Incorrect email or password" for invalid-credential', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signInStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenThrow(Exception('[firebase_auth/invalid-credential] bad creds'));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mock)));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('LoginScreen shows error for invalid-email', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signInStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenThrow(Exception('[firebase_auth/invalid-email]'));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mock)));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email.'), findsOneWidget);
  });

  testWidgets('LoginScreen shows error for user-not-found', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signInStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenThrow(Exception('[firebase_auth/user-not-found]'));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mock)));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('No account found for this email.'), findsOneWidget);
  });

  testWidgets('LoginScreen shows error for wrong-password', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signInStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenThrow(Exception('[firebase_auth/wrong-password]'));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mock)));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('LoginScreen shows generic error for unknown exception', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signInStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenThrow(Exception('some unknown error'));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mock)));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to sign in right now. Please try again.'), findsOneWidget);
  });

  testWidgets('LoginScreen calls continueAsGuest when Continue as Guest is tapped', (tester) async {
    final mock = MockAuthService();
    bool called = false;
    when(() => mock.continueAsGuest()).thenAnswer((_) async {
      called = true;
      return AppUser.guest();
    });

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(authService: mock, onGuestContinue: () {}),
    ));
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('RegisterScreen renders controls', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: authService)));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Account type'), findsOneWidget);
    expect(find.text('Student'), findsWidgets);
    expect(find.text('Teacher'), findsWidgets);
  });

  testWidgets('RegisterScreen shows error for email-already-in-use', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signUpStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
      role: any(named: 'role'),
    )).thenThrow(Exception('[firebase_auth/email-already-in-use]'));

    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: mock)));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsOneWidget);
  });

  testWidgets('RegisterScreen shows error for invalid-email', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signUpStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
      role: any(named: 'role'),
    )).thenThrow(Exception('[firebase_auth/invalid-email]'));

    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: mock)));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email.'), findsOneWidget);
  });

  testWidgets('RegisterScreen shows error for weak-password', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signUpStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
      role: any(named: 'role'),
    )).thenThrow(Exception('[firebase_auth/weak-password]'));

    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: mock)));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
  });

  testWidgets('RegisterScreen shows generic error for unknown exception', (tester) async {
    final mock = MockAuthService();
    when(() => mock.signUpStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
      role: any(named: 'role'),
    )).thenThrow(Exception('something went wrong'));

    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: mock)));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to create account right now. Please try again.'), findsOneWidget);
  });

  testWidgets('RegisterScreen switches selected role to Teacher', (tester) async {
    final mock = MockAuthService();
    UserRole? capturedRole;
    when(() => mock.signUpStudentOrTeacher(
      email: any(named: 'email'),
      password: any(named: 'password'),
      role: any(named: 'role'),
    )).thenAnswer((invocation) async {
      capturedRole = invocation.namedArguments[const Symbol('role')] as UserRole;
      return AppUser(uid: '1', email: 'a@b.com', role: UserRole.teacher, isGuest: false);
    });

    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: mock)));

    // Switch to Teacher via SegmentedButton
    await tester.tap(find.text('Teacher'));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(capturedRole, UserRole.teacher);
  });
}