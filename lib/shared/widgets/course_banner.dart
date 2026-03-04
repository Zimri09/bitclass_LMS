import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Preset banner definitions for courses (Google Classroom–style).
///
/// A [thumbnailUrl] that starts with `preset:` is resolved to a gradient banner.
/// Otherwise it is treated as a network image URL.
class CourseBannerPresets {
  CourseBannerPresets._();

  /// All available presets — order matters for the picker grid.
  static const List<BannerPreset> all = [
    BannerPreset(
      id: 'blue-teal',
      label: 'Ocean',
      colors: [Color(0xFF0D47A1), Color(0xFF00796B)],
      icon: Icons.waves,
    ),
    BannerPreset(
      id: 'purple-pink',
      label: 'Sunset',
      colors: [Color(0xFF6A1B9A), Color(0xFFC2185B)],
      icon: Icons.wb_twilight,
    ),
    BannerPreset(
      id: 'teal-green',
      label: 'Forest',
      colors: [Color(0xFF00695C), Color(0xFF2E7D32)],
      icon: Icons.park,
    ),
    BannerPreset(
      id: 'indigo-cyan',
      label: 'Sky',
      colors: [Color(0xFF283593), Color(0xFF0097A7)],
      icon: Icons.cloud,
    ),
    BannerPreset(
      id: 'orange-red',
      label: 'Ember',
      colors: [Color(0xFFE65100), Color(0xFFC62828)],
      icon: Icons.local_fire_department,
    ),
    BannerPreset(
      id: 'cyan-blue',
      label: 'Arctic',
      colors: [Color(0xFF006064), Color(0xFF01579B)],
      icon: Icons.ac_unit,
    ),
    BannerPreset(
      id: 'green-lime',
      label: 'Spring',
      colors: [Color(0xFF1B5E20), Color(0xFF827717)],
      icon: Icons.eco,
    ),
    BannerPreset(
      id: 'deep-purple',
      label: 'Cosmos',
      colors: [Color(0xFF311B92), Color(0xFF4A148C)],
      icon: Icons.auto_awesome,
    ),
  ];

  /// Resolve a preset ID to its definition.
  static BannerPreset? fromId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Check whether a [thumbnailUrl] is a preset reference.
  static bool isPreset(String? url) => url != null && url.startsWith('preset:');

  /// Extract the preset ID from a `preset:xxx` URL.
  static String? presetId(String? url) {
    if (url == null || !url.startsWith('preset:')) return null;
    return url.substring(7);
  }

  /// Build the stored value for a preset.
  static String toUrl(String presetId) => 'preset:$presetId';
}

/// Data class for a single banner preset.
class BannerPreset {
  final String id;
  final String label;
  final List<Color> colors;
  final IconData icon;

  const BannerPreset({
    required this.id,
    required this.label,
    required this.colors,
    required this.icon,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared widget that renders a course banner from thumbnailUrl
// ═══════════════════════════════════════════════════════════════════════════════

/// Renders the appropriate banner for a course.
///
/// - `preset:xxx` → gradient banner with icon
/// - `http(s)://…` → network image
/// - `null` → plain fallback with icon
class CourseBannerWidget extends StatelessWidget {
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// Optional dark overlay (useful for text on top). 0..1.
  final double darkenOpacity;

  const CourseBannerWidget({
    super.key,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.darkenOpacity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(8);

    if (CourseBannerPresets.isPreset(thumbnailUrl)) {
      final preset = CourseBannerPresets.fromId(
        CourseBannerPresets.presetId(thumbnailUrl)!,
      );
      if (preset != null) {
        return _buildPresetBanner(preset, br);
      }
    }

    if (thumbnailUrl != null && thumbnailUrl!.startsWith('http')) {
      return _buildNetworkImage(br);
    }

    return _buildFallback(br);
  }

  Widget _buildPresetBanner(BannerPreset preset, BorderRadius br) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          colors: preset.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative pattern
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              preset.icon,
              size: (height ?? 100) * 0.9,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Icon(
              preset.icon,
              size: 28,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          // Dark overlay
          if (darkenOpacity > 0)
            Container(
              decoration: BoxDecoration(
                borderRadius: br,
                color: Colors.black.withValues(alpha: darkenOpacity),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNetworkImage(BorderRadius br) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        color: AppColors.surface,
        image: DecorationImage(
          image: NetworkImage(thumbnailUrl!),
          fit: BoxFit.cover,
          colorFilter: darkenOpacity > 0
              ? ColorFilter.mode(
                  Colors.black.withValues(alpha: darkenOpacity),
                  BlendMode.darken,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFallback(BorderRadius br) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: br, color: AppColors.surface),
      child: Center(
        child: Icon(
          Icons.code,
          size: (height ?? 80) * 0.45,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
