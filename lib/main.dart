import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

bool isE2EMode = const bool.fromEnvironment('E2E_TEST', defaultValue: false);

// coverage:ignore-start
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CampusGuideApp());
}
// coverage:ignore-end

class CampusGuideApp extends StatelessWidget {
  const CampusGuideApp({super.key, this.home});

  final Widget? home;// home

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Guide',
      debugShowCheckedModeBanner: false,
      /*theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

       */
      theme: AppTheme.light(),

      home: home ?? const AuthGate(),
    );
  }
}