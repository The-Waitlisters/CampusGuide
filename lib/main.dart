import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

final bool isE2EMode = const bool.fromEnvironment('E2E_TEST', defaultValue: false);

void main() {
  runApp(const CampusGuideApp());
}

class CampusGuideApp extends StatelessWidget {
  const CampusGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}