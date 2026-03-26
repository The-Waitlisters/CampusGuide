import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../services/auth/auth_service.dart';
import '../home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  Widget build(BuildContext context) {
    // Guest path (no Firebase auth)
    if (_authService.isGuestMode) {
      return const HomeScreen(role: UserRole.guest); // coverage:ignore-line
    }

    // Authenticated path (Firebase user stream)
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        // Not logged in -> show login
        if (user == null) {
          return LoginScreen(
            authService: _authService,
            onGuestContinue: () => setState(() {}),
          );
        }

        // Logged in -> resolve role from Firestore profile
        return FutureBuilder<AppUser?>(
          future: _authService.getCurrentAppUser(),
          builder: (context, appUserSnapshot) {
            if (appUserSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (appUserSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Failed to load user profile.\n${appUserSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final appUser = appUserSnapshot.data;

            if (appUser == null) {
              return LoginScreen(
                authService: _authService,
                onGuestContinue: () => setState(() {}),
              );
            }

            // Safety: if profile is malformed/missing role, fallback to guest
            final role = appUser.role;
            if (role == UserRole.guest && !appUser.isGuest) {
              return HomeScreen(role: UserRole.guest, authService: _authService); // coverage:ignore-line
            }

            return HomeScreen(role: role, authService: _authService); // coverage:ignore-line
          },
        );
      },
    );
  }
}