import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/notifications/data/models/notification_model.dart';
import 'package:bitclass/features/notifications/data/models/notification_settings.dart';

void main() {
  group('NotificationModel', () {
    test('creates a valid notification with all fields', () {
      final notification = NotificationModel(
        id: 'notif-1',
        userId: 'user-1',
        type: NotificationType.newLesson,
        title: 'New Lesson Available',
        body: 'Check out the new lesson on Flutter widgets',
        isRead: false,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(notification.id, 'notif-1');
      expect(notification.type, NotificationType.newLesson);
      expect(notification.title, 'New Lesson Available');
      expect(notification.isRead, false);
    });

    test('toJson creates valid map', () {
      final notification = NotificationModel(
        id: 'notif-1',
        userId: 'user-1',
        type: NotificationType.assignmentDue,
        title: 'Assignment Due Soon',
        body: 'Your assignment is due tomorrow',
        isRead: true,
        createdAt: DateTime(2024, 1, 1),
        courseId: 'course-1',
      );

      final json = notification.toJson();

      expect(json['id'], 'notif-1');
      expect(json['type'], 'assignmentDue');
      expect(json['isRead'], true);
      expect(json['courseId'], 'course-1');
    });

    test('fromJson creates valid notification', () {
      final json = {
        'id': 'notif-1',
        'userId': 'user-1',
        'type': 'quizAvailable',
        'title': 'Quiz Available',
        'body': 'A new quiz is available',
        'isRead': false,
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final notification = NotificationModel.fromJson(json);

      expect(notification.id, 'notif-1');
      expect(notification.type, NotificationType.quizAvailable);
      expect(notification.isRead, false);
    });

    test('copyWith creates new instance with updated fields', () {
      final notification = NotificationModel(
        id: 'notif-1',
        userId: 'user-1',
        type: NotificationType.announcement,
        title: 'Announcement',
        body: 'Important update',
        isRead: false,
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = notification.copyWith(isRead: true);

      expect(updated.isRead, true);
      expect(updated.id, notification.id);
      expect(updated.type, notification.type);
    });
  });

  group('NotificationType enum', () {
    test('has all expected values', () {
      expect(NotificationType.values.length, 12);
      expect(
        NotificationType.values.contains(NotificationType.courseUpdate),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.newLesson),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.newAssignment),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.assignmentDue),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.assignmentGraded),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.quizAvailable),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.quizGraded),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.discussionReply),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.discussionMention),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.announcement),
        true,
      );
      expect(
        NotificationType.values.contains(NotificationType.enrollment),
        true,
      );
      expect(NotificationType.values.contains(NotificationType.general), true);
    });
  });

  group('NotificationSettings', () {
    test('creates settings with defaults', () {
      final settings = NotificationSettings(
        userId: 'user-1',
        pushEnabled: true,
        emailEnabled: false,
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(settings.pushEnabled, true);
      expect(settings.emailEnabled, false);
      expect(settings.quietHoursEnabled, false);
    });

    test('isTypeEnabled returns true for enabled types', () {
      final settings = NotificationSettings(
        userId: 'user-1',
        pushEnabled: true,
        emailEnabled: true,
        typeSettings: {
          NotificationType.newLesson: true,
          NotificationType.announcement: true,
          NotificationType.general: false,
        },
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(settings.isTypeEnabled(NotificationType.newLesson), true);
      expect(settings.isTypeEnabled(NotificationType.announcement), true);
      expect(settings.isTypeEnabled(NotificationType.general), false);
    });

    test('isTypeEnabled returns true by default for unset types', () {
      final settings = NotificationSettings(
        userId: 'user-1',
        pushEnabled: true,
        emailEnabled: true,
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(settings.isTypeEnabled(NotificationType.newLesson), true);
    });

    test('copyWith creates new instance with updated fields', () {
      final settings = NotificationSettings(
        userId: 'user-1',
        pushEnabled: true,
        emailEnabled: false,
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = settings.copyWith(emailEnabled: true);

      expect(updated.emailEnabled, true);
      expect(updated.pushEnabled, settings.pushEnabled);
    });
  });
}
