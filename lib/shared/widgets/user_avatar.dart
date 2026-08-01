import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Displays a user's current profile image with a consistent fallback.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? fallbackColor;
  final Color? fallbackIconColor;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackColor,
    this.fallbackIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    final fallback = _fallback();

    return Semantics(
      image: true,
      label: 'Profile picture',
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: normalizedUrl == null || normalizedUrl.isEmpty
              ? fallback
              : CachedNetworkImage(
                  key: ValueKey(normalizedUrl),
                  imageUrl: normalizedUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: fallbackColor ?? AppColors.primary.withValues(alpha: 0.16),
      child: Icon(
        Icons.person_outline,
        color: fallbackIconColor ?? AppColors.primary,
        size: radius * 1.15,
      ),
    );
  }
}
