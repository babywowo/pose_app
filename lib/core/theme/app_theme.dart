import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryBg = Color(0xFF1A1A2E);
  static const Color surfaceBg = Color(0xFF16213E);
  static const Color cardBg = Color(0xFF0F3460);
  static const Color accent = Color(0xFF4ECCA3);
  static const Color accentDark = Color(0xFF38A387);
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF4ECCA3);
  static const Color warning = Color(0xFFFF8A50);
  static const Color error = Color(0xFFFF5252);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primaryBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentDark,
        surface: AppColors.surfaceBg,
        error: AppColors.error,
        onPrimary: AppColors.primaryBg,
        onSecondary: AppColors.primaryBg,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surfaceBg,
        indicatorColor: AppColors.accent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 57,
            fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        labelLarge: TextStyle(
            color: AppColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.primaryBg,
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
