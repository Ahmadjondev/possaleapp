import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_colors_extension.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, ext: AppColorsExtension.dark);

  static ThemeData get light =>
      _build(brightness: Brightness.light, ext: AppColorsExtension.light);

  static ThemeData _build({
    required Brightness brightness,
    required AppColorsExtension ext,
  }) {
    final colorScheme = brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            secondary: AppColors.accentHover,
            surface: Color(0xFF1E1E1E),
            error: AppColors.danger,
          )
        : const ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            secondary: AppColors.accentHover,
            surface: Color(0xFFFFFFFF),
            error: AppColors.danger,
          );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: ext.background,
      colorScheme: colorScheme,
      extensions: [ext],
      cardTheme: CardThemeData(
        color: ext.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: ext.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.textPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: BorderSide(color: ext.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(0, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        hintStyle: TextStyle(color: ext.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ext.surface,
        contentTextStyle: TextStyle(color: ext.textPrimary),
      ),
      dividerTheme: DividerThemeData(color: ext.border, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: ext.surface,
        foregroundColor: ext.textPrimary,
        elevation: 0,
      ),
    );
  }
}
