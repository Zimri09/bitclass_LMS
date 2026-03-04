import 'package:flutter/material.dart';

/// BitClass color palette - Dark theme with neon accents
class AppColors {
  AppColors._();

  // Primary background colors
  static const Color background = Color(0xFF0D1117);
  static const Color backgroundSecondary = Color(0xFF161B22);
  static const Color surface = Color(0xFF21262D);
  static const Color surfaceLight = Color(0xFF30363D);

  // Accent colors - Neon cyan/green
  static const Color primary = Color(0xFF00D9FF);
  static const Color primaryDark = Color(0xFF00A8CC);
  static const Color secondary = Color(0xFF39FF14);
  static const Color secondaryDark = Color(0xFF2BC40F);

  // Text colors
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  // Border colors
  static const Color border = Color(0xFF30363D);
  static const Color borderFocus = Color(0xFF58A6FF);

  // Status colors
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color info = Color(0xFF58A6FF);

  // Glow colors for cards
  static const Color glowPrimary = Color(0x3300D9FF);
  static const Color glowSecondary = Color(0x3339FF14);

  // Code editor colors
  static const Color codeBackground = Color(0xFF0D1117);
  static const Color codeLineNumber = Color(0xFF484F58);
  static const Color codeSelection = Color(0xFF264F78);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, backgroundSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
