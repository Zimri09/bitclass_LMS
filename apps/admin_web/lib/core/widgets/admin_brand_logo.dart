import 'package:flutter/material.dart';

/// The canonical BitClass mark used by the administration website.
class AdminBrandLogo extends StatelessWidget {
  static const assetPath = 'assets/branding/bitclass_logo.png';

  final double size;
  final double? borderRadius;

  const AdminBrandLogo({
    super.key,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        semanticLabel: 'BitClass logo',
      ),
    );
  }
}
