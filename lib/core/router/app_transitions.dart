import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions for the app
class AppTransitions {
  /// Fade transition for main navigation
  static CustomTransitionPage<T> fadeTransition<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Slide from right transition for detail screens
  static CustomTransitionPage<T> slideFromRight<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Slide from bottom transition for modals
  static CustomTransitionPage<T> slideFromBottom<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Scale and fade transition for highlighted content
  static CustomTransitionPage<T> scaleTransition<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;

        var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);

        var scaleAnimation = Tween(
          begin: 0.9,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
      transitionDuration: duration,
    );
  }
}
