import 'package:intl/intl.dart';

/// Formats the original creation time shown on quizzes and activities.
String formatPostedDateTime(DateTime createdAt) {
  final formatted = DateFormat(
    "MMM d, y 'at' h:mm a",
  ).format(createdAt.toLocal());
  return 'Posted: $formatted';
}
