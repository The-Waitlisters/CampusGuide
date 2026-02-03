import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Waitlisters'),
      ),
      body: const Center(
        child: Text(
          'Campus Guide is running',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
