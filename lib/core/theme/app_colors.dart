import 'package:flutter/material.dart';

/// BitClass color palette — dark (default) + light variants
class AppColors {
  AppColors._();

  // Active theme status (updated in main.dart)
  static bool isDarkMode = true;

  // ── Primary background colors ──────────────────────────────────────────────
  static Color get background => isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA);
  static Color get backgroundSecondary => isDarkMode ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
  static Color get surface => isDarkMode ? const Color(0xFF21262D) : const Color(0xFFEEF1F5);
  static Color get surfaceLight => isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2E6EC);

  // ── Light palette constants ───────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFEEF1F5);
  static const Color lightSurfaceLight = Color(0xFFE2E6EC);

  // ── Accent colors — Neon cyan / green ────────────────────────────────────
  static const Color primary = Color(0xFF00B4D8);
  static const Color primaryDark = Color(0xFF00A8CC);
  static const Color secondary = Color(0xFF2DC653);
  static const Color secondaryDark = Color(0xFF2BC40F);

  // ── Text colors ────────────────────────────────────────────────────────────
  static Color get textPrimary => isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1A202C);
  static Color get textSecondary => isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF4A5568);
  static Color get textMuted => isDarkMode ? const Color(0xFF6E7681) : const Color(0xFF718096);

  // ── Light palette text constants ──────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF1A202C);
  static const Color lightTextSecondary = Color(0xFF4A5568);
  static const Color lightTextMuted = Color(0xFF718096);

  // ── Border colors ─────────────────────────────────────────────────────────
  static Color get border => isDarkMode ? const Color(0xFF30363D) : const Color(0xFFD1D9E0);
  static const Color lightBorder = Color(0xFFD1D9E0);
  static const Color borderFocus = Color(0xFF58A6FF);

  // ── Status colors (shared) ────────────────────────────────────────────────
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color info = Color(0xFF58A6FF);

  // ── Glow / accent overlay ─────────────────────────────────────────────────
  static const Color glowPrimary = Color(0x3300B4D8);
  static const Color glowSecondary = Color(0x332DC653);

  // ── Code editor ───────────────────────────────────────────────────────────
  static const Color codeBackground = Color(0xFF0D1117);
  static const Color codeLineNumber = Color(0xFF484F58);
  static const Color codeSelection = Color(0xFF264F78);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => LinearGradient(
    colors: [surface, backgroundSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Context-aware resolver ────────────────────────────────────────────────
  /// Returns the correct [AppColorScheme] for the current brightness.
  static AppColorScheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColorScheme.dark() : AppColorScheme.light();
  }
}

/// A resolved set of semantic colors for the current theme brightness.
class AppColorScheme {
  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;

  const AppColorScheme._({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
  });

  factory AppColorScheme.dark() => AppColorScheme._(
    background: AppColors.background,
    backgroundSecondary: AppColors.backgroundSecondary,
    surface: AppColors.surface,
    surfaceLight: AppColors.surfaceLight,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
  );

  factory AppColorScheme.light() => AppColorScheme._(
    background: AppColors.lightBackground,
    backgroundSecondary: AppColors.lightBackgroundSecondary,
    surface: AppColors.lightSurface,
    surfaceLight: AppColors.lightSurfaceLight,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
  );
}
