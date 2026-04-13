import 'package:flutter/material.dart';

/// Maximum number of digits allowed in any UZS money input field.
/// Covers up to 999,999,999,999 UZS (≈ 999 billion). Change here to adjust globally.
const kMaxMoneyInputDigits = 12;

/// POS-optimized color palette — dark-first design
class AppColors {
  AppColors._();

  // Backgrounds
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceLight = Color(0xFF2A2A2A);
  static const border = Color(0xFF333333);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B0);
  static const textMuted = Color(0xFF666666);

  // Accent & semantic
  static const accent = Color(0xFF2563EB);
  static const accentHover = Color(0xFF3B82F6);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF06B6D4);
  static const purple = Color(0xFF9333EA);
}
