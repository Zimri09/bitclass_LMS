import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// BitClass text styles - Monospace for code, clean sans-serif for content
class AppTextStyles {
  AppTextStyles._();

  // Monospace font family for headings and code
  static String get monoFontFamily => GoogleFonts.jetBrainsMono().fontFamily!;

  // Sans-serif font family for body text
  static String get sansFontFamily => GoogleFonts.inter().fontFamily!;

  // Headings - Monospace
  static TextStyle get h1 => GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => GoogleFonts.jetBrainsMono(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => GoogleFonts.jetBrainsMono(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get h4 => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body text - Sans-serif
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Labels and captions
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  // Code text
  static TextStyle get code => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static TextStyle get codeSmall => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Button text
  static TextStyle get buttonLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.background,
  );

  static TextStyle get buttonMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.background,
  );

  // Navigation
  static TextStyle get navItem => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get navItemActive => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
