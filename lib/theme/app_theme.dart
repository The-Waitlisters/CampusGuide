import 'package:flutter/material.dart';

class AppTheme {
  // Concordia-inspired colors
  static const burgundy = Color(0xFF912338);
  static const darkBlue = Color(0xFF004085);
  static const lightGrey = Color(0xFFF0F0F0);
  static const darkText = Color(0xFF2C2C2C);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: burgundy),
      scaffoldBackgroundColor: lightGrey,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: burgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkBlue,
          side: const BorderSide(color: darkBlue),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightGrey,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}