import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:proj/models/app_user.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/screens/auth/auth_gate.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

class _DisabledGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

class _StreamAuthService extends AuthService {
  _StreamAuthService({required this.stream})
      : super(
    auth: MockFirebaseAuth(),
    profileService: MockUserProfileService(),
  );
  final Stream<User?> stream;
  @override
  Stream<User?> get authStateChanges => stream;
}

class _FakeAuthGateService extends AuthService {
  _FakeAuthGateService({
    required this.stream,
    required this.currentUserFuture,
    this.guestMode = false,
  }) : super(
    auth: MockFirebaseAuth(),
    profileService: MockUserProfileService(),
  );

  final Stream<User?> stream;
  final Future<AppUser?> Function() currentUserFuture;
  final bool guestMode;

  @override
  Stream<User?> get authStateChanges => stream;

  @override
  bool get isGuestMode => guestMode;

  @override
  Future<AppUser?> getCurrentAppUser() => currentUserFuture();
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: '');
    registerFallbackValue(UserRole.user);
  });

  // ── AuthGate widget tests ────────────────────────────────────────────────

  testWidgets('AuthGate shows LoginScreen when user is unauthenticated', (tester) async {
    final service = AuthService(
      auth: MockFirebaseAuth(signedIn: false),
      profileService: MockUserProfileService(),
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('AuthGate onGuestContinue triggers setState rebuild', (tester) async {
    final service = AuthService(
      auth: MockFirebaseAuth(signedIn: false),
      profileService: MockUserProfileService(),
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    // Trigger the onGuestContinue callback to exercise setState
    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    login.onGuestContinue?.call();
    await tester.pump();

    // Widget rebuilt — still shows LoginScreen (not in guest mode)
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('AuthGate shows loading indicator while auth stream is waiting', (tester) async {
    final controller = StreamController<User?>();
    final service = _StreamAuthService(stream: controller.stream);

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await controller.close();
  });

  testWidgets('AuthGate shows error view when profile loading throws', (tester) async {
    final service = _FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => throw StateError('profile failed'),
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load user profile.'), findsOneWidget);
  });

  testWidgets('AuthGate shows LoginScreen when app user resolves to null', (tester) async {
    final service = _FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => null,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('AuthGate shows HomeScreen directly when in guest mode', (tester) async {
    GeolocatorPlatform.instance = _DisabledGeolocator();

    final service = _FakeAuthGateService(
      stream: const Stream.empty(),
      currentUserFuture: () async => null,
      guestMode: true,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump(Duration.zero);

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('AuthGate shows loading indicator while profile future is pending', (tester) async {
    final profileCompleter = Completer<AppUser?>();
    final service = _FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () => profileCompleter.future,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    profileCompleter.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('AuthGate shows HomeScreen when profile resolves to a valid AppUser', (tester) async {
    GeolocatorPlatform.instance = _DisabledGeolocator();

    const appUser = AppUser(
      uid: 'u1',
      email: 'user@test.com',
      role: UserRole.user,
      firstName: 'Jane',
      isGuest: false,
    );

    final service = _FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => appUser,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });


  testWidgets('AuthGate LoginScreen onGuestContinue called when appUser is null', (tester) async {
    // Covers line 81: onGuestContinue on LoginScreen shown when signed-in user has null profile
    final service = _FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => null,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump(); // stream delivers user
    await tester.pump(); // FutureBuilder resolves null -> LoginScreen

    expect(find.byType(LoginScreen), findsOneWidget);

    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    login.onGuestContinue?.call();
    await tester.pump(); // FutureBuilder enters waiting state
    await tester.pump(); // future resolves null -> LoginScreen again

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('AuthGate shows guest HomeScreen when role is guest but isGuest is false', (tester) async {
    // Covers lines 86, 92, 93: role == UserRole.guest && !appUser.isGuest branch
    GeolocatorPlatform.instance = _DisabledGeolocator();

    const appUser = AppUser(
      uid: 'u1',
      email: 'user@test.com',
      role: UserRole.guest,
      firstName: 'Jane',
      isGuest: false,
    );

    final service = _FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => appUser,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  // ── AuthService unit tests ───────────────────────────────────────────────

  group('AuthService', () {
    late MockFirebaseAuth mockAuth;
    late MockUserProfileService mockProfile;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockProfile = MockUserProfileService();
      authService = AuthService(auth: mockAuth, profileService: mockProfile);
    });

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

      when(() => mockProfile.getUserProfile(any())).thenAnswer(
            (_) async => {'role': 'user', 'firstName': 'Taylor', 'lastName': 'Kim'},
      );

      final user = await authService.signIn(email: 'user@test.com', password: 'abcdef');

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

      when(() => mockProfile.getUserProfile(any())).thenAnswer(
            (_) async => {'role': 'guest', 'firstName': 'Broken', 'lastName': 'User'},
      );

      expect(
            () => authService.signIn(email: 'broken@test.com', password: 'abcdef'),
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
      when(() => mockProfile.getUserProfile(any())).thenAnswer(
            (_) async => {'role': 'user', 'firstName': 'Test', 'lastName': 'User'},
      );
      final service = AuthService(auth: signedInAuth, profileService: mockProfile);

      final user = await service.getCurrentAppUser();
      expect(user?.role, UserRole.user);
      expect(user?.isGuest, isFalse);
    });
  });
}