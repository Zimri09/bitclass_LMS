import 'package:bitclass/features/notifications/data/models/models.dart';
import 'package:bitclass/features/notifications/data/services/push_topic_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const courseId = '2f234e31-cd12-41af-a33d-3cdaf1f3fefa';

  test('push disabled produces no topics', () {
    final settings = NotificationSettings.defaults(
      'student-1',
    ).copyWith(pushEnabled: false);

    expect(
      PushTopicPlanner.topicsFor(
        role: 'student',
        courseIds: const [courseId],
        settings: settings,
      ),
      isEmpty,
    );
  });

  test('topics include role, courses, and enabled notification types', () {
    final settings = NotificationSettings.defaults('student-1').copyWith(
      typeSettings: {
        for (final type in NotificationType.values) type: false,
        NotificationType.newLesson: true,
        NotificationType.announcement: true,
      },
    );

    expect(
      PushTopicPlanner.topicsFor(
        role: 'Student',
        courseIds: const [courseId],
        settings: settings,
      ),
      {
        'role_student',
        'course_$courseId',
        'type_newlesson',
        'type_announcement',
      },
    );
  });

  test('unsafe topic characters are normalized', () {
    final settings = NotificationSettings.defaults('user-1').copyWith(
      typeSettings: {for (final type in NotificationType.values) type: false},
    );

    expect(
      PushTopicPlanner.topicsFor(
        role: 'Course Admin',
        courseIds: const ['course/id'],
        settings: settings,
      ),
      {'role_course_admin', 'course_course_id'},
    );
  });

  test(
    'instructor topics include submission and discussion activity types',
    () {
      final settings = NotificationSettings.defaults('instructor-1').copyWith(
        typeSettings: {
          for (final type in NotificationType.values) type: false,
          NotificationType.assignmentSubmitted: true,
          NotificationType.quizSubmitted: true,
          NotificationType.discussionActivity: true,
          NotificationType.enrollment: true,
        },
      );

      expect(
        PushTopicPlanner.topicsFor(
          role: 'instructor',
          courseIds: const [courseId],
          settings: settings,
        ),
        {
          'role_instructor',
          'course_$courseId',
          'type_assignmentsubmitted',
          'type_quizsubmitted',
          'type_discussionactivity',
          'type_enrollment',
        },
      );
    },
  );
}
