import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/screens/auth/auth_gate.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';
import 'package:proj/models/app_user.dart';
import 'package:proj/models/user_role.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

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

  testWidgets(
      'AuthGate shows error view when profile loading throws', (tester) async {
    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => throw StateError('profile failed'),
    );

    await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Failed to load user profile.'), findsOneWidget);
  });

  testWidgets('AuthGate returns LoginScreen when app user resolves to null', (
      tester) async {
    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async => null,
    );

    await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: service)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'AuthGate builds HomeScreen when app user is resolved', (tester) async {
    final service = FakeAuthGateService(
      stream: Stream<User?>.value(MockUser(uid: 'u1', email: 'e@test.com')),
      currentUserFuture: () async =>
      const AppUser(
        uid: 'u1',
        email: 'e@test.com',
        role: UserRole.user,
        firstName: 'Sam',
        lastName: 'User',
        isGuest: false,
      ),
    );

    await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: service)));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}