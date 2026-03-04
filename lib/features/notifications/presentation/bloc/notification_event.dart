import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Notification Bloc Events
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Load all notifications
class LoadNotifications extends NotificationEvent {
  final String userId;

  const LoadNotifications({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Refresh notifications
class RefreshNotifications extends NotificationEvent {
  final String userId;

  const RefreshNotifications({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Mark a notification as read
class MarkNotificationRead extends NotificationEvent {
  final String notificationId;

  const MarkNotificationRead({required this.notificationId});

  @override
  List<Object?> get props => [notificationId];
}

/// Mark all notifications as read
class MarkAllNotificationsRead extends NotificationEvent {
  final String userId;

  const MarkAllNotificationsRead({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Delete a notification
class DeleteNotification extends NotificationEvent {
  final String notificationId;

  const DeleteNotification({required this.notificationId});

  @override
  List<Object?> get props => [notificationId];
}

/// Clear all notifications
class ClearAllNotifications extends NotificationEvent {
  final String userId;

  const ClearAllNotifications({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Load notification settings
class LoadNotificationSettings extends NotificationEvent {
  final String userId;

  const LoadNotificationSettings({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Toggle push notifications
class TogglePushNotifications extends NotificationEvent {
  final String userId;
  final bool enabled;

  const TogglePushNotifications({required this.userId, required this.enabled});

  @override
  List<Object?> get props => [userId, enabled];
}

/// Toggle a specific notification type
class ToggleNotificationType extends NotificationEvent {
  final String userId;
  final NotificationType type;
  final bool enabled;

  const ToggleNotificationType({
    required this.userId,
    required this.type,
    required this.enabled,
  });

  @override
  List<Object?> get props => [userId, type, enabled];
}

/// New notification received (from push)
class NotificationReceived extends NotificationEvent {
  final NotificationModel notification;

  const NotificationReceived({required this.notification});

  @override
  List<Object?> get props => [notification];
}
