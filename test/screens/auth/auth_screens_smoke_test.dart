import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/models/app_user.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/screens/auth/register_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

class MockAuthService extends Mock implements AuthService {}

class FakeAuthService extends AuthService {
  FakeAuthService({
    this.signInThrows,
    this.signUpThrows,
  }) : super(
    auth: MockFirebaseAuth(),
    profileService: MockUserProfileService(),
  );

  final Object? signInThrows;
  final Object? signUpThrows;
  bool continueAsGuestCalled = false;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInThrows != null) throw signInThrows!;
    return const AppUser(
      uid: 'u1',
      email: 'ok@test.com',
      role: UserRole.user,
      firstName: 'Ok',
      lastName: 'User',
      isGuest: false,
    );
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (signUpThrows != null) throw signUpThrows!;
    return AppUser(
      uid: 'u2',
      email: email,
      role: UserRole.user,
      firstName: firstName,
      lastName: lastName,
      isGuest: false,
    );
  }

  @override
  Future<AppUser> continueAsGuest() async {
    continueAsGuestCalled = true;
    return AppUser.guest();
  }
}


void main() {
  late AuthService authService;
  late MockUserProfileService mockProfile;

  setUp(() {
    final mockAuth = MockFirebaseAuth();
    mockProfile = MockUserProfileService();

    when(() => mockProfile.createUserProfile(
      uid: any(named: 'uid'),
      email: any(named: 'email'),
      firstName: any(named: 'firstName'),
      lastName: any(named: 'lastName'),
    )).thenAnswer((_) async {});
    when(() => mockProfile.getUserProfile(any())).thenAnswer((_) async => throw Exception('not used'));

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
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
  });

  testWidgets('LoginScreen maps auth errors to friendly messages', (tester) async {
    final fake = FakeAuthService(signInThrows: Exception('invalid-email'));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: fake)));
    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email.'), findsOneWidget);
  });

  testWidgets('LoginScreen maps user-not-found error', (tester) async {
    final fake = FakeAuthService(signInThrows: Exception('user-not-found'));
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: fake)));
    await tester.enterText(find.byType(TextField).at(0), 'x@test.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('No account found for this email.'), findsOneWidget);
  });

  testWidgets('LoginScreen maps wrong-password error', (tester) async {
    final fake = FakeAuthService(signInThrows: Exception('wrong-password'));
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: fake)));
    await tester.enterText(find.byType(TextField).at(0), 'x@test.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('LoginScreen continue as guest triggers callback', (tester) async {
    final fake = FakeAuthService();
    var callbackCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authService: fake,
          onGuestContinue: () => callbackCalled = true,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Continue as Guest'));
    await tester.pumpAndSettle();

    expect(fake.continueAsGuestCalled, isTrue);
    expect(callbackCalled, isTrue);
  });

  testWidgets('LoginScreen navigates to RegisterScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('RegisterScreen validates first/last name before sign up', (tester) async {
    final fake = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: fake)));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter both first and last name.'), findsOneWidget);
  });

  testWidgets('RegisterScreen maps weak-password error to message', (tester) async {
    final fake = FakeAuthService(signUpThrows: Exception('weak-password'));
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: fake)));

    await tester.enterText(find.byType(TextField).at(0), 'Sam');
    await tester.enterText(find.byType(TextField).at(1), 'User');
    await tester.enterText(find.byType(TextField).at(2), 'sam@test.com');
    await tester.enterText(find.byType(TextField).at(3), '123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
  });

  testWidgets('RegisterScreen pops after successful signup', (tester) async {
    final fake = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegisterScreen(authService: fake),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Sam');
    await tester.enterText(find.byType(TextField).at(1), 'User');
    await tester.enterText(find.byType(TextField).at(2), 'sam@test.com');
    await tester.enterText(find.byType(TextField).at(3), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
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