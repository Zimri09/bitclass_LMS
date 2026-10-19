import 'package:bitclass/shared/widgets/app_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in [600.0, 900.0, 1366.0, 1920.0, 2560.0]) {
    for (final sidebar in [72.0, 260.0]) {
      testWidgets('centers content at $viewport with a $sidebar sidebar', (
        tester,
      ) async {
        tester.view.physicalSize = Size(viewport, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        double? localWidth;
        await tester.pumpWidget(
          MaterialApp(
            home: Row(
              children: [
                SizedBox(width: sidebar),
                Expanded(
                  child: AppPageFrame(
                    child: Builder(
                      builder: (context) {
                        localWidth = MediaQuery.sizeOf(context).width;
                        return const Scaffold(
                          key: Key('page'),
                          body: SizedBox.expand(),
                          bottomNavigationBar: SizedBox(height: 64),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final rect = tester.getRect(find.byKey(const Key('page')));
        expect(rect.width, lessThanOrEqualTo(AppPageFrame.standardWidth));
        expect(rect.left - sidebar, greaterThanOrEqualTo(16));
        expect(rect.left - sidebar, closeTo(viewport - rect.right, 0.01));
        expect(rect.height, 900);
        expect(localWidth, closeTo(rect.width, 0.01));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'reading and workspace caps retain keyboard and text scale data',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final maxWidth in [
        AppPageFrame.readingWidth,
        AppPageFrame.workspaceWidth,
      ]) {
        MediaQueryData? pageMedia;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1920, 900),
                viewInsets: EdgeInsets.only(bottom: 250),
                textScaler: TextScaler.linear(1.5),
              ),
              child: AppPageFrame(
                maxWidth: maxWidth,
                child: Builder(
                  builder: (context) {
                    pageMedia = MediaQuery.of(context);
                    return const SizedBox.expand(key: Key('content'));
                  },
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(const Key('content'))).width,
          maxWidth,
        );
        expect(pageMedia!.viewInsets.bottom, 250);
        expect(pageMedia!.textScaler.scale(16), 24);
      }
    },
  );
}

