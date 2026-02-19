// lib/theme/app_theme.dart - SafeNest Premium Theme (FIXED)
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SafeNestTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary), // ✅ FIXED: Use your actual color
    cardTheme: CardThemeData(
      elevation: 12,
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      shadowColor: Colors.black26,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 18, height: 1.4),
    ),
    // 👴 Elderly-friendly additions
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 12,
      selectedItemColor: AppColors.primary,
      backgroundColor: Colors.white,
    ),
  );

  // Glassmorphism card for sensor status (SafeNest signature ✨)
  static BoxDecoration glassCard(Color color) => BoxDecoration(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: color.withOpacity(0.2), width: 1),
    boxShadow: [
      BoxShadow(
        color: color.withOpacity(0.15),
        blurRadius: 25,
        spreadRadius: 0,
        offset: const Offset(0, 12),
      ),
      // Subtle inner glow for premium feel
      BoxShadow(
        color: Colors.white.withOpacity(0.4),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(-8, -8),
      ),
    ],
  );
}
