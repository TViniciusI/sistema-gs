import 'package:flutter/material.dart';

class GsTheme {
  static const navy = Color(0xFF0C1F33);
  static const brass = Color(0xFFC59E39);
  static const paper = Color(0xFFF4F0E6);
  static const ink = Color(0xFF1A2330);

  static ThemeData get data {
    final base = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: base.copyWith(
        primary: navy,
        secondary: brass,
        surface: paper,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: paper,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      useMaterial3: true,
    );
  }
}
