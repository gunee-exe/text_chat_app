import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the light & dark [ThemeData] for Textify.
///
/// Typography is Fredoka: weight 500 for names/headers, 400 for body/secondary,
/// and 600 is reserved for the app name only (set explicitly where used).
/// Nothing renders below 10px. Screens paint their own flat background + top
/// glow via `GradientBackground`, so scaffolds stay transparent.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(
        brightness: Brightness.light,
        textPrimary: AppColors.textPrimaryLight,
        textSecondary: AppColors.textSecondaryLight,
        card: AppColors.lightCardFill,
        divider: AppColors.lightDivider,
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        textPrimary: AppColors.textPrimaryDark,
        textSecondary: AppColors.textSecondaryDark,
        card: AppColors.darkCardFill,
        divider: AppColors.darkDivider,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color textPrimary,
    required Color textSecondary,
    required Color card,
    required Color divider,
  }) {
    final base = ThemeData(brightness: brightness);
    final textTheme = GoogleFonts.fredokaTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    // Headers/names default to weight 500; body/secondary to 400.
    final tuned = textTheme.copyWith(
      headlineLarge: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w500),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      bodySmall: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: brightness,
      ).copyWith(primary: AppColors.accent),
      textTheme: tuned,
      dividerColor: divider,
      cardColor: card,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: tuned.titleLarge?.copyWith(color: textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color.fromARGB(255, 35, 52, 83)
            : Colors.white,
        contentTextStyle: tuned.bodyMedium?.copyWith(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 16, 161, 223),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: tuned.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
