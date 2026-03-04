import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/notification_repository.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// Bloc for managing notifications
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository notificationRepository;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _unreadCountSubscription;

  NotificationBloc({required this.notificationRepository})
    : super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<RefreshNotifications>(_onRefreshNotifications);
    on<MarkNotificationRead>(_onMarkNotificationRead);
    on<MarkAllNotificationsRead>(_onMarkAllNotificationsRead);
    on<DeleteNotification>(_onDeleteNotification);
    on<ClearAllNotifications>(_onClearAllNotifications);
    on<LoadNotificationSettings>(_onLoadNotificationSettings);
    on<TogglePushNotifications>(_onTogglePushNotifications);
    on<ToggleNotificationType>(_onToggleNotificationType);
    on<NotificationReceived>(_onNotificationReceived);
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationsLoading());
    try {
      final notifications = await notificationRepository.getNotifications(
        event.userId,
      );
      final unreadCount = await notificationRepository.getUnreadCount(
        event.userId,
      );
      emit(
        NotificationsLoaded(
          notifications: notifications,
          unreadCount: unreadCount,
        ),
      );
    } catch (e) {
      emit(NotificationError(message: 'Failed to load notifications: $e'));
    }
  }

  Future<void> _onRefreshNotifications(
    RefreshNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final notifications = await notificationRepository.getNotifications(
        event.userId,
      );
      final unreadCount = await notificationRepository.getUnreadCount(
        event.userId,
      );
      emit(
        NotificationsLoaded(
          notifications: notifications,
          unreadCount: unreadCount,
        ),
      );
    } catch (e) {
      emit(NotificationError(message: 'Failed to refresh notifications: $e'));
    }
  }

  Future<void> _onMarkNotificationRead(
    MarkNotificationRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await notificationRepository.markAsRead(event.notificationId);
      emit(NotificationMarkedRead(notificationId: event.notificationId));
    } catch (e) {
      emit(NotificationError(message: 'Failed to mark notification read: $e'));
    }
  }

  Future<void> _onMarkAllNotificationsRead(
    MarkAllNotificationsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await notificationRepository.markAllAsRead(event.userId);
      emit(AllNotificationsMarkedRead());
    } catch (e) {
      emit(NotificationError(message: 'Failed to mark all as read: $e'));
    }
  }

  Future<void> _onDeleteNotification(
    DeleteNotification event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await notificationRepository.deleteNotification(event.notificationId);
      emit(NotificationDeleted(notificationId: event.notificationId));
    } catch (e) {
      emit(NotificationError(message: 'Failed to delete notification: $e'));
    }
  }

  Future<void> _onClearAllNotifications(
    ClearAllNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await notificationRepository.clearAllNotifications(event.userId);
      emit(AllNotificationsCleared());
    } catch (e) {
      emit(NotificationError(message: 'Failed to clear notifications: $e'));
    }
  }

  Future<void> _onLoadNotificationSettings(
    LoadNotificationSettings event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationSettingsLoading());
    try {
      final settings = await notificationRepository.getSettings(event.userId);
      emit(NotificationSettingsLoaded(settings: settings));
    } catch (e) {
      emit(NotificationError(message: 'Failed to load settings: $e'));
    }
  }

  Future<void> _onTogglePushNotifications(
    TogglePushNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final settings = await notificationRepository.togglePushEnabled(
        event.userId,
        event.enabled,
      );
      emit(NotificationSettingsUpdated(settings: settings));
    } catch (e) {
      emit(NotificationError(message: 'Failed to update settings: $e'));
    }
  }

  Future<void> _onToggleNotificationType(
    ToggleNotificationType event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final settings = await notificationRepository.toggleNotificationType(
        event.userId,
        event.type,
        event.enabled,
      );
      emit(NotificationSettingsUpdated(settings: settings));
    } catch (e) {
      emit(NotificationError(message: 'Failed to update settings: $e'));
    }
  }

  Future<void> _onNotificationReceived(
    NotificationReceived event,
    Emitter<NotificationState> emit,
  ) async {
    notificationRepository.simulateNewNotification(event.notification);
    final currentState = state;
    if (currentState is NotificationsLoaded) {
      emit(
        currentState.copyWith(
          notifications: [event.notification, ...currentState.notifications],
          unreadCount: currentState.unreadCount + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    return super.close();
  }
}
