import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Notification Bloc States
abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class NotificationInitial extends NotificationState {}

/// Loading notifications
class NotificationsLoading extends NotificationState {}

/// Notifications loaded successfully
class NotificationsLoaded extends NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [notifications, unreadCount];

  NotificationsLoaded copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Loading settings
class NotificationSettingsLoading extends NotificationState {}

/// Settings loaded successfully
class NotificationSettingsLoaded extends NotificationState {
  final NotificationSettings settings;

  const NotificationSettingsLoaded({required this.settings});

  @override
  List<Object?> get props => [settings];
}

/// Settings updated
class NotificationSettingsUpdated extends NotificationState {
  final NotificationSettings settings;

  const NotificationSettingsUpdated({required this.settings});

  @override
  List<Object?> get props => [settings];
}

/// Error state
class NotificationError extends NotificationState {
  final String message;

  const NotificationError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Notification marked as read
class NotificationMarkedRead extends NotificationState {
  final String notificationId;

  const NotificationMarkedRead({required this.notificationId});

  @override
  List<Object?> get props => [notificationId];
}

/// All notifications marked as read
class AllNotificationsMarkedRead extends NotificationState {}

/// Notification deleted
class NotificationDeleted extends NotificationState {
  final String notificationId;

  const NotificationDeleted({required this.notificationId});

  @override
  List<Object?> get props => [notificationId];
}

/// All notifications cleared
class AllNotificationsCleared extends NotificationState {}
