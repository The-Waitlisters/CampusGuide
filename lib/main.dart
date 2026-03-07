import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

bool isE2EMode = const bool.fromEnvironment('E2E_TEST', defaultValue: false);

// coverage:ignore-start
void main() {
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: home ?? const HomeScreen(),
    );
  }
}