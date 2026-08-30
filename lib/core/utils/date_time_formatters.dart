import 'package:intl/intl.dart';

/// Formats the original creation time shown on quizzes and activities.
String formatPostedDateTime(DateTime createdAt) {
  final formatted = DateFormat(
    "MMM d, y 'at' h:mm a",
  ).format(createdAt.toLocal());
  return 'Posted: $formatted';
}

/// Formats a coursework deadline in the student's local time zone.
String formatDueDateTime(DateTime dueDate) {
  final formatted = DateFormat(
    "MMM d, y 'at' h:mm a",
  ).format(dueDate.toLocal());
  return 'Due: $formatted';
}
