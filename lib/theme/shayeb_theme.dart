import 'package:flutter/material.dart';

/// Authentic Egyptian Café Visual Identity & Color System.
class ShayebColors {
  ShayebColors._();

  static const Color primaryDarkGreen = Color(0xFF123B32);
  static const Color deepTableGreen = Color(0xFF092B25);
  static const Color warmWoodBrown = Color(0xFF67432D);
  static const Color darkWoodBorder = Color(0xFF472C1B);
  static const Color goldenAccent = Color(0xFFD5AA59);
  static const Color softGold = Color(0xFFEAC87F);
  static const Color cream = Color(0xFFF5E9D1);
  static const Color cardWhite = Color(0xFFFFF9EF);
  static const Color richRed = Color(0xFFB93B3B);
  static const Color darkCharcoal = Color(0xFF171D1A);
  static const Color successGreen = Color(0xFF42A878);

  static const RadialGradient feltTableGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.95,
    colors: [
      Color(0xFF184D41),
      primaryDarkGreen,
      deepTableGreen,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient woodFrameGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7D5339),
      warmWoodBrown,
      darkWoodBorder,
    ],
  );

  static const LinearGradient goldButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      softGold,
      goldenAccent,
      Color(0xFFB88B3A),
    ],
  );
}

class ShayebTheme {
  ShayebTheme._();

  static ThemeData buildTheme() {
    const colorScheme = ColorScheme.dark(
      primary: ShayebColors.goldenAccent,
      onPrimary: ShayebColors.darkCharcoal,
      secondary: ShayebColors.warmWoodBrown,
      onSecondary: ShayebColors.cream,
      surface: ShayebColors.primaryDarkGreen,
      onSurface: ShayebColors.cream,
      error: ShayebColors.richRed,
      onError: ShayebColors.cardWhite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ShayebColors.deepTableGreen,
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        backgroundColor: ShayebColors.primaryDarkGreen,
        foregroundColor: ShayebColors.cream,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: ShayebColors.goldenAccent,
        ),
      ),
      cardTheme: CardThemeData(
        color: ShayebColors.primaryDarkGreen,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: ShayebColors.goldenAccent, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ShayebColors.goldenAccent,
          foregroundColor: ShayebColors.darkCharcoal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ShayebColors.cream,
          side: const BorderSide(color: ShayebColors.goldenAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ShayebColors.deepTableGreen.withValues(alpha: 0.75),
        labelStyle: const TextStyle(color: ShayebColors.cream),
        hintStyle: TextStyle(color: ShayebColors.cream.withValues(alpha: 0.55)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ShayebColors.goldenAccent, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ShayebColors.softGold, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ShayebColors.richRed, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ShayebColors.warmWoodBrown,
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: ShayebColors.cream,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ShayebColors.goldenAccent),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
