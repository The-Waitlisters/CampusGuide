import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:proj/screens/auth/auth_gate.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';
import 'package:proj/models/app_user.dart';
import 'package:proj/models/user_role.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

/// Minimal geolocator stub: reports location disabled so HomeScreen
/// returns early from _tryInitLocationTracking without platform calls.
class _DisabledGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

// Fake service to control auth stream state (for waiting test)
class FakeWaitingAuthService extends AuthService {
  FakeWaitingAuthService({required this.stream})
      : super(
    auth: MockFirebaseAuth(),
    profileService: MockUserProfileService(),
  );

  final Stream<User?> stream;

  @override
  Stream<User?> get authStateChanges => stream;
}

class FakeAuthGateService extends AuthService {
  FakeAuthGateService({
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
  testWidgets('AuthGate shows LoginScreen when user is unauthenticated', (
      tester) async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final mockProfile = MockUserProfileService();

    final service = AuthService(
      auth: mockAuth,
      profileService: mockProfile,
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authService: service)),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    login.onGuestContinue?.call();
    await tester.pump();
  });

  testWidgets(
      'AuthGate shows loading indicator while auth stream is waiting', (
      tester) async {
    // Never emits and never closes -> stays in waiting
    final controller = StreamController<User?>();

    final service = FakeWaitingAuthService(stream: controller.stream);

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authService: service)),
    );

    // initial frame: waiting
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await controller.close();
  });

  testWidgets('AuthGate shows error view when profile loading throws', (tester) async {
    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => throw StateError('profile failed'),
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load user profile.'), findsOneWidget);
  });

  testWidgets('AuthGate returns LoginScreen when app user resolves to null', (tester) async {
    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => null,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('AuthGate shows HomeScreen directly when in guest mode', (tester) async {
    GeolocatorPlatform.instance = _DisabledGeolocator();

    final service = FakeAuthGateService(
      stream: const Stream.empty(),
      currentUserFuture: () async => null,
      guestMode: true,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    // One pump is enough: isGuestMode is checked synchronously in build(),
    // so HomeScreen is in the tree on the first frame.
    await tester.pump(Duration.zero);

    expect(find.byType(HomeScreen), findsOneWidget);

    // Dispose before real DataParser / map futures can hang pumpAndSettle.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('AuthGate shows loading indicator while profile future is pending', (tester) async {
    final profileCompleter = Completer<AppUser?>();
    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () => profileCompleter.future,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump(); // delivers user from stream; FutureBuilder enters waiting state

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

    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => appUser,
    );

    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: service)));
    await tester.pump(Duration.zero); // stream delivers user
    await tester.pump(Duration.zero); // FutureBuilder resolves appUser → HomeScreen built

    expect(find.byType(HomeScreen), findsOneWidget);

    // Dispose before real DataParser / map futures can hang pumpAndSettle.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

}