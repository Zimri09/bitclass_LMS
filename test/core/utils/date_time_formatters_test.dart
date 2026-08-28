import 'package:bitclass/core/utils/date_time_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats a posted timestamp with the date and time', () {
    final createdAt = DateTime(2026, 8, 28, 12, 18);

    expect(formatPostedDateTime(createdAt), 'Posted: Aug 28, 2026 at 12:18 PM');
  });
}
