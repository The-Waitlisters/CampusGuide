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
    if (_authService.isGuestMode) {
      return const HomeScreen(role: UserRole.guest);
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: _buildAuthState,
    );
  }

  Widget _buildAuthState(
    BuildContext context,
    AsyncSnapshot<User?> authSnapshot,
  ) {
    if (authSnapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingScaffold();
    }

    final user = authSnapshot.data;
    if (user == null) {
      return _buildLoginScreen();
    }

    return FutureBuilder<AppUser?>(
      future: _authService.getCurrentAppUser(),
      builder: _buildAppUserState,
    );
  }

  Widget _buildAppUserState(
    BuildContext context,
    AsyncSnapshot<AppUser?> appUserSnapshot,
  ) {
    if (appUserSnapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingScaffold();
    }

    if (appUserSnapshot.hasError) {
      return _buildProfileError(appUserSnapshot.error);
    }

    final appUser = appUserSnapshot.data;
    if (appUser == null) {
      return _buildLoginScreen();
    }

    return _buildHomeForAppUser(appUser);
  }

  Widget _buildLoadingScaffold() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildLoginScreen() {
    return LoginScreen(
      authService: _authService,
      onGuestContinue: () => setState(() {}),
    );
  }

  Widget _buildProfileError(Object? error) {
    return Scaffold(
      body: Center(
        child: Text(
          'Failed to load user profile.\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildHomeForAppUser(AppUser appUser) {
    final role = appUser.role;

    if (role == UserRole.guest && !appUser.isGuest) {
      return HomeScreen(
        role: UserRole.guest,
        authService: _authService,
        displayName: appUser.firstName,
      );
    }

    return HomeScreen(
      role: role,
      displayName: appUser.firstName,
      authService: _authService,
    );
  }
}
