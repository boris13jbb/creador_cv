import 'package:flutter/material.dart';

class AppTheme {
  // Colores principales extraídos de tus requerimientos
  static const Color primaryDark = Color(0xFF1A1A2E);    // Fondo encabezado
  static const Color secondaryGreen = Color(0xFF2D6A4F); // Secciones y Totales
  static const Color accentGreen = Color(0xFF40916C);
  static const Color lightGray = Color(0xFFF5F5F5);      // Filas alternas y notas
  static const Color successGreen = Color(0xFFD8F3DC);   // Fondo "Incluye"
  static const Color errorRed = Color(0xFFFFE5E5);       // Fondo "No incluye"

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: secondaryGreen,
        primary: primaryDark,
        secondary: secondaryGreen,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryGreen,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondaryGreen, width: 2),
        ),
      ),
    );
  }
}
