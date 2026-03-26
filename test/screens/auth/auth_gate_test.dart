import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/screens/auth/auth_gate.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';

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

void main() {
  testWidgets('AuthGate shows LoginScreen when user is unauthenticated', (tester) async {
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
  });

  testWidgets('AuthGate shows loading indicator while auth stream is waiting', (tester) async {
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
}