import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

/// Repository for managing notifications.
class NotificationRepository {
  static const String _notificationsTable = 'notifications';
  static const String _settingsTable = 'notification_settings';
  static const String _deviceTokensTable = 'device_tokens';

  static const String _demoStudentUserId = 'demo-user-1';
  static const String _demoInstructorUserId = 'demo-instructor-1';
  static const String _legacyDemoUserId = 'demo-user';

  final SupabaseClient? _supabase;

  // Demo data storage
  final List<NotificationModel> _notifications = [];
  final Map<String, NotificationSettings> _settingsByUser = {};
  int _unreadCount = 0;

  // Stream controllers for real-time updates
  final _notificationsController =
      StreamController<List<NotificationModel>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  final _settingsController =
      StreamController<NotificationSettings>.broadcast();

  /// Stream of notifications
  Stream<List<NotificationModel>> get notificationsStream =>
      _notificationsController.stream;

  /// Stream of unread count
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Stream of settings updates
  Stream<NotificationSettings> get settingsStream => _settingsController.stream;

  NotificationRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    final now = DateTime.now();

    _notifications.addAll([
      NotificationModel(
        id: 'notif-1',
        userId: _demoStudentUserId,
        type: NotificationType.newLesson,
        title: 'New Lesson Available',
        body: 'Flutter State Management: Introduction to BLoC is now available',
        createdAt: now.subtract(const Duration(minutes: 30)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/lessons/lesson-3',
      ),
      NotificationModel(
        id: 'notif-2',
        userId: _demoStudentUserId,
        type: NotificationType.assignmentDue,
        title: 'Assignment Due Soon',
        body: 'Flutter Counter App assignment is due in 2 days',
        createdAt: now.subtract(const Duration(hours: 2)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/assignments/assignment-1',
      ),
      NotificationModel(
        id: 'notif-3',
        userId: _demoStudentUserId,
        type: NotificationType.discussionReply,
        title: 'New Reply to Your Thread',
        body: 'Prof. Johnson replied to "Help with setState"',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 5)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/discussions/channel-2/threads/thread-3',
      ),
      NotificationModel(
        id: 'notif-4',
        userId: _demoStudentUserId,
        type: NotificationType.quizGraded,
        title: 'Quiz Results Ready',
        body: 'Your Dart Fundamentals quiz has been graded: 85%',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/quizzes/quiz-1/result',
      ),
      NotificationModel(
        id: 'notif-5',
        userId: _demoStudentUserId,
        type: NotificationType.announcement,
        title: 'Course Announcement',
        body: 'Office hours this Friday have been moved to 3 PM',
        createdAt: now.subtract(const Duration(days: 2)),
        courseId: 'course-1',
      ),
      NotificationModel(
        id: 'notif-6',
        userId: _demoStudentUserId,
        type: NotificationType.assignmentGraded,
        title: 'Assignment Graded',
        body: 'Python FizzBuzz Solution received 95/100',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 3)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/assignments/assignment-3',
      ),
      NotificationModel(
        id: 'notif-7',
        userId: _demoStudentUserId,
        type: NotificationType.enrollment,
        title: 'Welcome to the Course!',
        body: 'You have successfully enrolled in Flutter Development',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 7)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1',
      ),
      NotificationModel(
        id: 'notif-inst-1',
        userId: _demoInstructorUserId,
        type: NotificationType.enrollment,
        title: 'New Student Enrollment',
        body: 'A new student enrolled in Introduction to Flutter',
        createdAt: now.subtract(const Duration(minutes: 20)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/students',
      ),
      NotificationModel(
        id: 'notif-inst-2',
        userId: _demoInstructorUserId,
        type: NotificationType.discussionMention,
        title: 'You were mentioned in a discussion',
        body: 'A student tagged you in Q&A: Widget lifecycle question',
        createdAt: now.subtract(const Duration(hours: 1)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/discussions',
      ),
      NotificationModel(
        id: 'notif-inst-3',
        userId: _demoInstructorUserId,
        type: NotificationType.newAssignment,
        title: 'Submission Waiting for Review',
        body: 'You have new assignment submissions to grade',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 4)),
        courseId: 'course-1',
        actionUrl: '/my-courses',
      ),
      NotificationModel(
        id: 'notif-inst-4',
        userId: _demoInstructorUserId,
        type: NotificationType.announcement,
        title: 'Instructor Reminder',
        body: 'Publish this week\'s lesson and quiz for Course 2',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
        courseId: 'course-2',
      ),
    ]);

    _settingsByUser[_demoStudentUserId] = NotificationSettings.defaults(
      _demoStudentUserId,
    );
    _settingsByUser[_demoInstructorUserId] = NotificationSettings.defaults(
      _demoInstructorUserId,
    );
    _updateUnreadCount();
  }

  String _normalizeDemoUserId(String userId) {
    if (userId == _legacyDemoUserId) {
      return _demoStudentUserId;
    }
    return userId;
  }

  bool _isDemoUserMatch(String storedUserId, String requestedUserId) {
    final normalizedStored = _normalizeDemoUserId(storedUserId);
    final normalizedRequested = _normalizeDemoUserId(requestedUserId);
    return normalizedStored == normalizedRequested;
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _unreadCountController.add(_unreadCount);
  }

  Map<String, dynamic> _rowToNotificationMap(Map<String, dynamic> row) {
    return {
      'userId': row['user_id'],
      'type': row['type'],
      'title': row['title'],
      'body': row['body'],
      'imageUrl': row['image_url'],
      'data': row['data'],
      'isRead': row['is_read'],
      'createdAt': row['created_at']?.toString(),
      'courseId': row['course_id'],
      'actionUrl': row['action_url'],
    };
  }

  NotificationModel _notificationFromRow(Map<String, dynamic> row) {
    return NotificationModel.fromMap(
      _rowToNotificationMap(row),
      row['id'] as String,
    );
  }

  Map<String, dynamic> _rowToSettingsMap(Map<String, dynamic> row) {
    return {
      'userId': row['user_id'],
      'pushEnabled': row['push_enabled'],
      'emailEnabled': row['email_enabled'],
      'typeSettings': row['type_settings'] ?? {},
      'quietHoursEnabled': row['quiet_hours_enabled'],
      'quietHoursStart': row['quiet_hours_start'],
      'quietHoursEnd': row['quiet_hours_end'],
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  NotificationSettings _settingsFromRow(Map<String, dynamic> row) {
    return NotificationSettings.fromMap(_rowToSettingsMap(row));
  }

  /// Get all notifications for a user
  Future<List<NotificationModel>> getNotifications(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _notifications
          .where((n) => _isDemoUserMatch(n.userId, userId))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final rows = await _supabase!
        .from(_notificationsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_notificationFromRow)
        .toList();
  }

  /// Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _notifications
          .where((n) => _isDemoUserMatch(n.userId, userId) && !n.isRead)
          .length;
    }

    final rows = await _supabase!
        .from(_notificationsTable)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (rows as List<dynamic>).length;
  }

  /// Mark a notification as read
  Future<NotificationModel> markAsRead(String notificationId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _updateUnreadCount();
        _notificationsController.add(_notifications);
        return _notifications[index];
      }
      throw Exception('Notification not found');
    }

    await _supabase!
        .from(_notificationsTable)
        .update({'is_read': true})
        .eq('id', notificationId);

    final row = await _supabase!
        .from(_notificationsTable)
        .select()
        .eq('id', notificationId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Notification not found');
    }

    return _notificationFromRow(row);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (var i = 0; i < _notifications.length; i++) {
        if (_isDemoUserMatch(_notifications[i].userId, userId) &&
            !_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _updateUnreadCount();
      _notificationsController.add(_notifications);
      return;
    }

    await _supabase!
        .from(_notificationsTable)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
      _notificationsController.add(_notifications);
      return;
    }

    await _supabase!
        .from(_notificationsTable)
        .delete()
        .eq('id', notificationId);
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      _notifications.removeWhere((n) => _isDemoUserMatch(n.userId, userId));
      _updateUnreadCount();
      _notificationsController.add(_notifications);
      return;
    }

    await _supabase!.from(_notificationsTable).delete().eq('user_id', userId);
  }

  /// Get notification settings
  Future<NotificationSettings> getSettings(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final normalizedUserId = _normalizeDemoUserId(userId);
      return _settingsByUser[normalizedUserId] ??
          NotificationSettings.defaults(normalizedUserId);
    }

    final row = await _supabase!
        .from(_settingsTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      final defaults = NotificationSettings.defaults(userId);
      await updateSettings(defaults);
      return defaults;
    }

    return _settingsFromRow(row);
  }

  /// Update notification settings
  Future<NotificationSettings> updateSettings(
    NotificationSettings settings,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final updated = settings.copyWith(updatedAt: DateTime.now());
      _settingsByUser[_normalizeDemoUserId(settings.userId)] = updated;
      _settingsController.add(updated);
      return updated;
    }

    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
    await _supabase!.from(_settingsTable).upsert({
      'user_id': updatedSettings.userId,
      'push_enabled': updatedSettings.pushEnabled,
      'email_enabled': updatedSettings.emailEnabled,
      'type_settings': updatedSettings.typeSettings.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'quiet_hours_enabled': updatedSettings.quietHoursEnabled,
      'quiet_hours_start': updatedSettings.quietHoursStart,
      'quiet_hours_end': updatedSettings.quietHoursEnd,
      'updated_at': updatedSettings.updatedAt.toIso8601String(),
    });
    _settingsController.add(updatedSettings);
    return updatedSettings;
  }

  /// Toggle push notifications
  Future<NotificationSettings> togglePushEnabled(
    String userId,
    bool enabled,
  ) async {
    final current = await getSettings(userId);
    return updateSettings(current.copyWith(pushEnabled: enabled));
  }

  /// Toggle a specific notification type
  Future<NotificationSettings> toggleNotificationType(
    String userId,
    NotificationType type,
    bool enabled,
  ) async {
    final current = await getSettings(userId);
    final newTypeSettings = Map<NotificationType, bool>.from(
      current.typeSettings,
    );
    newTypeSettings[type] = enabled;
    return updateSettings(current.copyWith(typeSettings: newTypeSettings));
  }

  /// Register device token for push notifications
  Future<void> registerDeviceToken(String userId, String token) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }

    await _supabase!.from(_deviceTokensTable).upsert({
      'user_id': userId,
      'token': token,
      'created_at': DateTime.now().toIso8601String(),
      'platform': 'flutter',
    });
  }

  /// Unregister device token
  Future<void> unregisterDeviceToken(String userId, String token) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }

    await _supabase!
        .from(_deviceTokensTable)
        .delete()
        .eq('user_id', userId)
        .eq('token', token);
  }

  /// Get the FCM token for this device
  Future<String?> getFcmToken() async {
    return null;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    return EnvironmentConfig.isDemoMode;
  }

  /// Subscribe to a topic (e.g., course updates)
  Future<void> subscribeToTopic(String topic) async {
    return;
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    return;
  }

  /// Simulate receiving a new notification (for demo)
  void simulateNewNotification(NotificationModel notification) async {
    if (EnvironmentConfig.isDemoMode) {
      _notifications.insert(0, notification);
      _updateUnreadCount();
      _notificationsController.add(_notifications);
      return;
    }

    await _supabase!.from(_notificationsTable).insert({
      'id': notification.id,
      'user_id': notification.userId,
      'type': notification.type.name,
      'title': notification.title,
      'body': notification.body,
      'image_url': notification.imageUrl,
      'data': notification.data,
      'is_read': notification.isRead,
      'created_at': notification.createdAt.toIso8601String(),
      'course_id': notification.courseId,
      'action_url': notification.actionUrl,
    });
  }

  void dispose() {
    _notificationsController.close();
    _unreadCountController.close();
    _settingsController.close();
  }
}
