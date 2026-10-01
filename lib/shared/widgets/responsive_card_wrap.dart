import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keeps card lists readable on phones and uses two compact columns on web.
class ResponsiveCardWrap extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final double maxCardWidth;
  final double minTwoColumnWidth;

  const ResponsiveCardWrap({
    super.key,
    required this.children,
    this.gap = 12,
    this.maxCardWidth = 600,
    this.minTwoColumnWidth = 820,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final twoColumns = kIsWeb && availableWidth >= minTwoColumnWidth;
        final cardWidth = kIsWeb
            ? math.min(
                maxCardWidth,
                twoColumns ? (availableWidth - gap) / 2 : availableWidth,
              )
            : availableWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
