import 'package:bitclass_notifications/bitclass_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GlobalKey<ScaffoldMessengerState> messenger;
  Future<void> mount(
    WidgetTester tester, {
    bool accessible = false,
    VoidCallback? onTap,
  }) async {
    messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messenger,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(accessibleNavigation: accessible),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: onTap ?? () {},
              child: const Text('Page action'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ordinary messages disappear after two seconds and quick exit', (
    tester,
  ) async {
    await mount(tester);
    messenger.currentState!.showAppSnackBar(
      const SnackBar(content: Text('Saved')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 2),
    );
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('latest replaces immediately and legacy queues never reappear', (
    tester,
  ) async {
    await mount(tester);
    messenger.currentState!.showSnackBar(const SnackBar(content: Text('Old')));
    messenger.currentState!.showSnackBar(
      const SnackBar(content: Text('Queued')),
    );
    await tester.pumpAndSettle();
    messenger.currentState!.showAppSnackBar(
      const SnackBar(content: Text('Latest')),
    );
    await tester.pump();
    expect(find.text('Old'), findsNothing);
    expect(find.text('Queued'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    messenger.currentState!.showAppSnackBar(
      const SnackBar(content: Text('Newest')),
    );
    await tester.pump();
    expect(find.text('Latest'), findsNothing);
    expect(find.text('Newest'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'duplicates do not restart the timer and may return after dismissal',
    (tester) async {
      await mount(tester);
      final first = messenger.currentState!.showAppSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      final duplicate = messenger.currentState!.showAppSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      expect(identical(first, duplicate), isTrue);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      final next = messenger.currentState!.showAppSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      expect(identical(first, next), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'preserves action callbacks and does not block page interactions',
    (tester) async {
      var retries = 0;
      var taps = 0;
      await mount(tester, onTap: () => taps++);
      messenger.currentState!.showAppSnackBar(
        SnackBar(
          content: const Text('Try again'),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Retry', onPressed: () => retries++),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      await tester.tap(find.text('Page action'));
      expect(taps, 1);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    },
  );

  for (final width in [360.0, 1280.0]) {
    testWidgets('readable floating messages fit a $width pixel view', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      messenger.currentState!.showAppSnackBar(
        const SnackBar(
          content: Text(
            'Your changes were saved successfully. You can continue working.',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).behavior,
        SnackBarBehavior.floating,
      );
    });
  }
}
