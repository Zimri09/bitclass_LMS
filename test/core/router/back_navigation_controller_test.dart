import 'package:bitclass/core/router/back_navigation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 8, 1, 12);

  test('a root back press outside Home returns to Home', () {
    final controller = BackNavigationController();

    expect(
      controller.handle(isHome: false, now: start),
      RootBackAction.navigateHome,
    );
  });

  test('Home requires two back presses within the exit window', () {
    final controller = BackNavigationController();

    expect(
      controller.handle(isHome: true, now: start),
      RootBackAction.promptExit,
    );
    expect(
      controller.handle(
        isHome: true,
        now: start.add(const Duration(seconds: 1)),
      ),
      RootBackAction.exitApp,
    );
  });

  test('an expired second press prompts again', () {
    final controller = BackNavigationController();

    controller.handle(isHome: true, now: start);

    expect(
      controller.handle(
        isHome: true,
        now: start.add(const Duration(seconds: 3)),
      ),
      RootBackAction.promptExit,
    );
  });

  test('leaving Home resets a pending exit', () {
    final controller = BackNavigationController();

    controller.handle(isHome: true, now: start);
    controller.handle(
      isHome: false,
      now: start.add(const Duration(milliseconds: 500)),
    );

    expect(
      controller.handle(
        isHome: true,
        now: start.add(const Duration(seconds: 1)),
      ),
      RootBackAction.promptExit,
    );
  });
}
