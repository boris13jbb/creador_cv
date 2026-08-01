import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

/// Tema Material 3 basado en tokens CV Maker.
class AppTheme {
  // Compatibilidad con usos existentes.
  static const Color primaryDark = AppColors.navy;
  static const Color secondaryGreen = AppColors.emerald;
  static const Color accentGreen = AppColors.emeraldBright;
  static const Color lightGray = AppColors.surface;
  static const Color successGreen = AppColors.successSoft;
  static const Color errorRed = AppColors.dangerSoft;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.emerald,
      onSecondary: Colors.white,
      tertiary: AppColors.amber,
      onTertiary: Colors.white,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.border,
    );

    final textTheme = GoogleFonts.sourceSans3TextTheme().copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        fontSize: 40,
        height: 1.15,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        fontSize: 28,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.sourceSans3(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.sourceSans3(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        fontSize: 16,
      ),
      bodyLarge: GoogleFonts.sourceSans3(
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        fontSize: 16,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.sourceSans3(
        fontWeight: FontWeight.w400,
        color: AppColors.inkMuted,
        fontSize: 14,
        height: 1.45,
      ),
      labelLarge: GoogleFonts.sourceSans3(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: AppElevations.none,
        titleTextStyle: GoogleFonts.fraunces(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        elevation: AppElevations.mid,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size(AppTouch.min, AppTouch.min),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size(AppTouch.min, AppTouch.min),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emerald,
          minimumSize: const Size(AppTouch.min, 40),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.amberSoft.withValues(alpha: 0.35),
        labelStyle: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: AppElevations.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.sourceSans3(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.emerald.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.sourceSans3(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.navy,
        selectedIconTheme: const IconThemeData(color: AppColors.emeraldBright),
        unselectedIconTheme: IconThemeData(
          color: Colors.white.withValues(alpha: 0.7),
        ),
        selectedLabelTextStyle: GoogleFonts.sourceSans3(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.sourceSans3(
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
