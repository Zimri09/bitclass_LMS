enum RootBackAction { navigateHome, promptExit, exitApp }

/// Decides what a root-level back press should do.
class BackNavigationController {
  BackNavigationController({this.exitWindow = const Duration(seconds: 2)});

  final Duration exitWindow;
  DateTime? _lastHomeBackPress;

  RootBackAction handle({required bool isHome, DateTime? now}) {
    if (!isHome) {
      reset();
      return RootBackAction.navigateHome;
    }

    final pressedAt = now ?? DateTime.now();
    final previousPress = _lastHomeBackPress;
    if (previousPress != null &&
        pressedAt.difference(previousPress) <= exitWindow) {
      reset();
      return RootBackAction.exitApp;
    }

    _lastHomeBackPress = pressedAt;
    return RootBackAction.promptExit;
  }

  void reset() => _lastHomeBackPress = null;
}
