import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centers a page in the space remaining beside navigation. The page keeps its
/// own scroll view, app bar, safe areas, and mobile content padding.
class AppPageFrame extends StatelessWidget {
  static const double standardWidth = 1120;
  static const double readingWidth = 960;
  static const double workspaceWidth = 1280;

  final Widget child;
  final double maxWidth;

  const AppPageFrame({
    super.key,
    required this.child,
    this.maxWidth = standardWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = (constraints.maxWidth * 0.025).clamp(16.0, 40.0);
        final width = math.min(
          maxWidth,
          math.max(0.0, constraints.maxWidth - gutter * 2),
        );
        final media = MediaQuery.of(context);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            // Existing pages using MediaQuery must respond to their available
            // content width, rather than the browser width including the rail.
            child: MediaQuery(
              data: media.copyWith(size: Size(width, media.size.height)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
