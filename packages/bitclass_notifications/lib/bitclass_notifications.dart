import 'package:flutter/material.dart';

/// Per-messenger state avoids leaking notifications across app windows/routes.
final _activeNotifications = Expando<_ActiveNotification>();

class _ActiveNotification {
  final Object identity;
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
  _ActiveNotification(this.identity, this.controller);
}

extension BitClassNotifications on ScaffoldMessengerState {
  /// Shows the latest message without a queue or restarting duplicate timers.
  ///
  /// For custom content, supply [notificationId] to identify duplicate actions.
  /// Text notifications are identified by their message, action and appearance.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
    SnackBar snackBar, {
    Object? notificationId,
  }) {
    final content = snackBar.content;
    final identity =
        notificationId ??
        (content is Text
            ? (
                content.data ?? content.textSpan?.toPlainText(),
                snackBar.action?.label,
                snackBar.backgroundColor,
                snackBar.key,
              )
            : content);
    final previous = _activeNotifications[this];
    if (previous != null && previous.identity == identity) {
      return previous.controller;
    }

    // Clear any legacy queue, then remove the visible message synchronously.
    clearSnackBars();
    removeCurrentSnackBar();
    final accessible =
        MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    final controller = showSnackBar(
      SnackBar(
        key: snackBar.key,
        content: snackBar.content,
        backgroundColor: snackBar.backgroundColor,
        elevation: snackBar.elevation,
        margin: snackBar.margin,
        padding: snackBar.padding,
        width: snackBar.width,
        shape: snackBar.shape,
        hitTestBehavior:
            snackBar.hitTestBehavior ?? HitTestBehavior.deferToChild,
        behavior: SnackBarBehavior.floating,
        action: snackBar.action,
        actionOverflowThreshold: snackBar.actionOverflowThreshold,
        showCloseIcon: snackBar.showCloseIcon,
        closeIconColor: snackBar.closeIconColor,
        duration: const Duration(seconds: 2),
        // Give assistive-technology users time to reach an action.
        persist: accessible && snackBar.action != null,
        onVisible: snackBar.onVisible,
        dismissDirection: snackBar.dismissDirection,
        clipBehavior: snackBar.clipBehavior,
      ),
      snackBarAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 150),
        reverseDuration: Duration(milliseconds: 100),
      ),
    );
    final active = _ActiveNotification(identity, controller);
    _activeNotifications[this] = active;
    controller.closed.then((_) {
      if (identical(_activeNotifications[this], active)) {
        _activeNotifications[this] = null;
      }
    });
    return controller;
  }
}
