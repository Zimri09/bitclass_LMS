import 'package:bitclass/core/errors/app_error.dart';
import 'package:bitclass/shared/widgets/loading_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline error state shows friendly message and retries', (
    tester,
  ) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            message:
                'RealtimeSubscribeException: WebSocketChannelException: '
                'SocketException: Failed host lookup',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Connection unavailable'), findsOneWidget);
    expect(find.text(noInternetConnectionMessage), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
