import 'package:bitclass/core/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notificationDestination', () {
    test('accepts registered main and nested course routes', () {
      expect(
        AppRoutes.notificationDestination('/notifications/settings'),
        '/notifications/settings',
      );
      expect(
        AppRoutes.notificationDestination(
          '/courses/course-1/discussions/general/threads/thread-1',
        ),
        '/courses/course-1/discussions/general/threads/thread-1',
      );
      expect(
        AppRoutes.notificationDestination(
          '/courses/course-1/quizzes/quiz-1/result',
        ),
        '/courses/course-1/quizzes/quiz-1/result',
      );
    });

    test('rejects empty, external, authentication, and unknown routes', () {
      expect(AppRoutes.notificationDestination(null), isNull);
      expect(AppRoutes.notificationDestination(''), isNull);
      expect(
        AppRoutes.notificationDestination('https://example.com/course'),
        isNull,
      );
      expect(AppRoutes.notificationDestination('/login'), isNull);
      expect(AppRoutes.notificationDestination('/unknown/page'), isNull);
    });
  });
}
