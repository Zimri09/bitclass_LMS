import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The canonical BitClass brand mark used across app and web surfaces.
class BitClassLogo extends StatelessWidget {
  static const assetPath = 'assets/branding/bitclass_logo.png';

  final double size;
  final double? borderRadius;
  final bool showGlow;

  const BitClassLogo({
    super.key,
    required this.size,
    this.borderRadius,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.glowPrimary,
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.05,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          semanticLabel: 'BitClass logo',
        ),
      ),
    );
  }
}
