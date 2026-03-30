import 'package:flutter/material.dart';

import '../../services/auth/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    this.onGuestContinue,
  });

  final AuthService authService;
  final VoidCallback? onGuestContinue;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _authMessageFromError(Object e) {
    final text = e.toString();
    if (text.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (text.contains('invalid-email')) {
      return 'Please enter a valid email.';
    }
    if (text.contains('user-not-found')) {
      return 'No account found for this email.';
    }
    if (text.contains('wrong-password')) {
      return 'Incorrect email or password.';
    }
    return 'Unable to sign in right now. Please try again.';
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // AuthGate StreamBuilder handles transition automatically
    } catch (e) {
      setState(() => _error = _authMessageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await widget.authService.continueAsGuest();
    widget.onGuestContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                      Image.asset('assets/branding/concordia_logo1.png', height: 56),
                    const Text(
                      'Campus Guide',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Concordia University',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Login'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RegisterScreen(authService: widget.authService),
                    ),
                  );
                },
                child: const Text('Create account'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _loading ? null : _continueAsGuest,
                child: const Text('Continue as Guest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}