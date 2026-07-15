import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Border radius constants shared across the app.
abstract final class AppRadius {
  static const double avatar = 11.0;
  static const double pill = 20.0;
  static const double inputBar = 22.0;
  static const double sheet = 28.0;
  static const double messageBubble = 18.0;
}

abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accentSolid,
      onPrimary: Colors.white,
      secondary: AppColors.accentSolid,
      onSecondary: Colors.white,
      surface: isDark ? AppColors.darkBg : AppColors.lightBg,
      onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
    );

    // Fredoka text theme: 400 body, 500 labels/names, 600 display only
    final baseTextTheme = GoogleFonts.fredokaTextTheme().copyWith(
      displayLarge: GoogleFonts.fredoka(
        fontWeight: FontWeight.w600,
        fontSize: 32,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      titleLarge: GoogleFonts.fredoka(
        fontWeight: FontWeight.w500,
        fontSize: 20,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      titleMedium: GoogleFonts.fredoka(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      bodyLarge: GoogleFonts.fredoka(
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      bodyMedium: GoogleFonts.fredoka(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
      bodySmall: GoogleFonts.fredoka(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
      ),
      labelSmall: GoogleFonts.fredoka(
        fontWeight: FontWeight.w400,
        fontSize: 10, // minimum font size per spec
        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
      ),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.fredoka(
          fontWeight: FontWeight.w500,
          fontSize: 20,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCardFill : AppColors.lightCardFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputBar),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputBar),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputBar),
          borderSide: const BorderSide(color: AppColors.accentSolid, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.inputBar),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        hintStyle: GoogleFonts.fredoka(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSolid,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w500, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSolid,
          textStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2530) : const Color(0xFF1E2530),
        contentTextStyle: GoogleFonts.fredoka(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF161B24) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
    );
  }
}
