import 'package:flutter/material.dart';

/// 存知主题：暖橙色调，呼应「收藏生活干货」的温暖感。
class AppTheme {
  static const Color primary = Color(0xFFE8590C); // 暖橙
  static const Color primaryDark = Color(0xFFB23A00);
  static const Color accent = Color(0xFFFF922B);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: accent,
        surface: const Color(0xFFFFFFFF),
        surfaceVariant: const Color(0xFFF5F0EA),
        background: const Color(0xFFFAF7F2),
        onBackground: const Color(0xFF2B2118),
        onSurface: const Color(0xFF2B2118),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF7F2),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAF7F2),
        foregroundColor: Color(0xFF2B2118),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF2B2118),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: const Color(0xFF1E1A16),
        surfaceVariant: const Color(0xFF2A2520),
        background: const Color(0xFF15120F),
        onBackground: const Color(0xFFEDE5DB),
        onSurface: const Color(0xFFEDE5DB),
      ),
      scaffoldBackgroundColor: const Color(0xFF15120F),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF15120F),
        foregroundColor: Color(0xFFEDE5DB),
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1A16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
