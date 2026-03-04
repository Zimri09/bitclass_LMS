import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;

import '../../../../core/config/environment.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/models.dart';

/// Repository for managing notifications
class NotificationRepository {
  // Firebase instances (null in demo mode)
  final FirebaseFirestore? _firestore;
  final fcm.FirebaseMessaging? _messaging;

  // Demo data storage
  final List<NotificationModel> _notifications = [];
  NotificationSettings? _settings;
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

  NotificationRepository()
    : _firestore = EnvironmentConfig.isDemoMode
          ? null
          : FirebaseFirestore.instance,
      _messaging = EnvironmentConfig.isDemoMode
          ? null
          : fcm.FirebaseMessaging.instance {
    final now = DateTime.now();

    _notifications.addAll([
      NotificationModel(
        id: 'notif-1',
        userId: 'demo-user',
        type: NotificationType.newLesson,
        title: 'New Lesson Available',
        body: 'Flutter State Management: Introduction to BLoC is now available',
        createdAt: now.subtract(const Duration(minutes: 30)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/lessons/lesson-3',
      ),
      NotificationModel(
        id: 'notif-2',
        userId: 'demo-user',
        type: NotificationType.assignmentDue,
        title: 'Assignment Due Soon',
        body: 'Flutter Counter App assignment is due in 2 days',
        createdAt: now.subtract(const Duration(hours: 2)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1/assignments/assignment-1',
      ),
      NotificationModel(
        id: 'notif-3',
        userId: 'demo-user',
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
        userId: 'demo-user',
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
        userId: 'demo-user',
        type: NotificationType.announcement,
        title: 'Course Announcement',
        body: 'Office hours this Friday have been moved to 3 PM',
        createdAt: now.subtract(const Duration(days: 2)),
        courseId: 'course-1',
      ),
      NotificationModel(
        id: 'notif-6',
        userId: 'demo-user',
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
        userId: 'demo-user',
        type: NotificationType.enrollment,
        title: 'Welcome to the Course!',
        body: 'You have successfully enrolled in Flutter Development',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 7)),
        courseId: 'course-1',
        actionUrl: '/courses/course-1',
      ),
    ]);

    _settings = NotificationSettings.defaults('demo-user');
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _unreadCountController.add(_unreadCount);
  }

  /// Get all notifications for a user
  Future<List<NotificationModel>> getNotifications(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _notifications.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final snapshot = await _firestore!
        .collection(FirestorePaths.notifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _notifications
          .where((n) => n.userId == userId && !n.isRead)
          .length;
    }

    final snapshot = await _firestore!
        .collection(FirestorePaths.notifications)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();

    return snapshot.count ?? 0;
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

    await _firestore!
        .collection(FirestorePaths.notifications)
        .doc(notificationId)
        .update({'isRead': true});

    final doc = await _firestore
        .collection(FirestorePaths.notifications)
        .doc(notificationId)
        .get();

    if (!doc.exists) {
      throw Exception('Notification not found');
    }

    return NotificationModel.fromMap(doc.data()!, doc.id);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (var i = 0; i < _notifications.length; i++) {
        if (_notifications[i].userId == userId && !_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _updateUnreadCount();
      _notificationsController.add(_notifications);
      return;
    }

    // Get all unread notifications for user
    final snapshot = await _firestore!
        .collection(FirestorePaths.notifications)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    // Batch update all to read
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
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

    await _firestore!
        .collection(FirestorePaths.notifications)
        .doc(notificationId)
        .delete();
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      _notifications.removeWhere((n) => n.userId == userId);
      _updateUnreadCount();
      _notificationsController.add(_notifications);
      return;
    }

    // Get all notifications for user
    final snapshot = await _firestore!
        .collection(FirestorePaths.notifications)
        .where('userId', isEqualTo: userId)
        .get();

    // Batch delete all
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Get notification settings
  Future<NotificationSettings> getSettings(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _settings ?? NotificationSettings.defaults(userId);
    }

    final doc = await _firestore!
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('settings')
        .doc('notifications')
        .get();

    if (!doc.exists) {
      // Create default settings if not exists
      final defaults = NotificationSettings.defaults(userId);
      await _firestore
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .set(defaults.toMap());
      return defaults;
    }

    return NotificationSettings.fromMap(doc.data()!);
  }

  /// Update notification settings
  Future<NotificationSettings> updateSettings(
    NotificationSettings settings,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      _settings = settings.copyWith(updatedAt: DateTime.now());
      _settingsController.add(_settings!);
      return _settings!;
    }

    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
    await _firestore!
        .collection(FirestorePaths.users)
        .doc(settings.userId)
        .collection('settings')
        .doc('notifications')
        .set(updatedSettings.toMap());
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

    // Save token to user's device tokens collection
    await _firestore!
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('deviceTokens')
        .doc(token)
        .set({
          'token': token,
          'createdAt': DateTime.now().toIso8601String(),
          'platform': _getPlatform(),
        });
  }

  /// Unregister device token
  Future<void> unregisterDeviceToken(String userId, String token) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }

    await _firestore!
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('deviceTokens')
        .doc(token)
        .delete();
  }

  /// Get the FCM token for this device
  Future<String?> getFcmToken() async {
    if (EnvironmentConfig.isDemoMode) {
      return null;
    }
    return await _messaging!.getToken();
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (EnvironmentConfig.isDemoMode) {
      return true;
    }

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == fcm.AuthorizationStatus.authorized;
  }

  /// Subscribe to a topic (e.g., course updates)
  Future<void> subscribeToTopic(String topic) async {
    if (EnvironmentConfig.isDemoMode) {
      return;
    }
    await _messaging!.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (EnvironmentConfig.isDemoMode) {
      return;
    }
    await _messaging!.unsubscribeFromTopic(topic);
  }

  String _getPlatform() {
    // This can be determined programmatically
    return 'flutter';
  }

  /// Simulate receiving a new notification (for demo)
  void simulateNewNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    _updateUnreadCount();
    _notificationsController.add(_notifications);
  }

  void dispose() {
    _notificationsController.close();
    _unreadCountController.close();
    _settingsController.close();
  }
}
