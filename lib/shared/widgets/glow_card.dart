import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A card widget with a subtle glow effect
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double glowIntensity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isHoverable;

  const GlowCard({
    super.key,
    required this.child,
    this.glowColor,
    this.glowIntensity = 0.3,
    this.borderRadius = 12,
    this.padding,
    this.margin,
    this.onTap,
    this.isHoverable = true,
  });

  @override
  Widget build(BuildContext context) {
    return _GlowCardContent(
      glowColor: glowColor ?? AppColors.primary,
      glowIntensity: glowIntensity,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      onTap: onTap,
      isHoverable: isHoverable,
      child: child,
    );
  }
}

class _GlowCardContent extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double glowIntensity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isHoverable;

  const _GlowCardContent({
    required this.child,
    required this.glowColor,
    required this.glowIntensity,
    required this.borderRadius,
    this.padding,
    this.margin,
    this.onTap,
    required this.isHoverable,
  });

  @override
  State<_GlowCardContent> createState() => _GlowCardContentState();
}

class _GlowCardContentState extends State<_GlowCardContent> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveGlowIntensity = widget.isHoverable && _isHovered
        ? widget.glowIntensity * 1.5
        : widget.glowIntensity;

    return MouseRegion(
      onEnter: widget.isHoverable
          ? (_) => setState(() => _isHovered = true)
          : null,
      onExit: widget.isHoverable
          ? (_) => setState(() => _isHovered = false)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: widget.margin,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _isHovered
                ? widget.glowColor.withOpacity(0.5)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withOpacity(effectiveGlowIntensity * 0.3),
              blurRadius: _isHovered ? 20 : 12,
              spreadRadius: _isHovered ? 2 : 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
