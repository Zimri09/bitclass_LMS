import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitclass/features/discussions/presentation/widgets/relative_timestamp.dart';

void main() {
  final now = DateTime.utc(2026, 7, 29, 12);

  test('formats newly created and elapsed timestamps', () {
    expect(formatRelativeTimestamp(now, now: now), 'Just now');
    expect(
      formatRelativeTimestamp(
        now.subtract(const Duration(seconds: 30)),
        now: now,
      ),
      '30s ago',
    );
    expect(
      formatRelativeTimestamp(
        now.subtract(const Duration(minutes: 2)),
        now: now,
      ),
      '2m ago',
    );
    expect(
      formatRelativeTimestamp(now.subtract(const Duration(hours: 1)), now: now),
      '1h ago',
    );
    expect(
      formatRelativeTimestamp(now.subtract(const Duration(days: 1)), now: now),
      '1d ago',
    );
  });

  test('clamps future timestamps caused by device or server clock skew', () {
    expect(
      formatRelativeTimestamp(now.add(const Duration(hours: 8)), now: now),
      'Just now',
    );
  });

  test('compares UTC instants regardless of the timestamp timezone', () {
    final localEquivalent = DateTime.parse('2026-07-29T19:59:30+08:00');
    expect(formatRelativeTimestamp(localEquivalent, now: now), '30s ago');
  });

  testWidgets('updates only the relative timestamp as time passes', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 7, 29, 12);
    var currentTime = timestamp;
    await tester.pumpWidget(
      MaterialApp(
        home: RelativeTimestamp(timestamp: timestamp, now: () => currentTime),
      ),
    );

    expect(find.text('Just now'), findsOneWidget);

    currentTime = currentTime.add(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('11s ago'), findsOneWidget);
  });
}
