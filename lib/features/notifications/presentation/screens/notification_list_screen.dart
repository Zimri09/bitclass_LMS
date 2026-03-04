import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/notification_repository.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

/// Screen showing list of notifications
class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationBloc(
        notificationRepository: context.read<NotificationRepository>(),
      )..add(const LoadNotifications(userId: 'demo-user')),
      child: const NotificationListView(),
    );
  }
}

class NotificationListView extends StatelessWidget {
  const NotificationListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/notifications/settings'),
            tooltip: 'Notification Settings',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'mark_all_read') {
                context.read<NotificationBloc>().add(
                  const MarkAllNotificationsRead(userId: 'demo-user'),
                );
              } else if (value == 'clear_all') {
                _showClearConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: AppColors.textSecondary),
                    SizedBox(width: 12),
                    Text(
                      'Mark all as read',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppColors.error),
                    SizedBox(width: 12),
                    Text(
                      'Clear all',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          if (state is AllNotificationsMarkedRead) {
            context.read<NotificationBloc>().add(
              const LoadNotifications(userId: 'demo-user'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All notifications marked as read'),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (state is AllNotificationsCleared) {
            context.read<NotificationBloc>().add(
              const LoadNotifications(userId: 'demo-user'),
            );
          } else if (state is NotificationDeleted) {
            context.read<NotificationBloc>().add(
              const LoadNotifications(userId: 'demo-user'),
            );
          }
        },
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const NotificationListSkeleton();
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NotificationBloc>().add(
                        const LoadNotifications(userId: 'demo-user'),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationsLoaded) {
            if (state.notifications.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<NotificationBloc>().add(
                  const RefreshNotifications(userId: 'demo-user'),
                );
              },
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.notifications.length,
                itemBuilder: (context, index) {
                  final notification = state.notifications[index];
                  return _buildNotificationCard(context, notification);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            color: AppColors.textSecondary,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        context.read<NotificationBloc>().add(
          DeleteNotification(notificationId: notification.id),
        );
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(context, notification),
        child: Container(
          color: notification.isRead
              ? Colors.transparent
              : AppColors.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getTypeColor(
                    notification.type,
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(notification.type),
                  color: _getTypeColor(notification.type),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) {
    // Mark as read
    if (!notification.isRead) {
      context.read<NotificationBloc>().add(
        MarkNotificationRead(notificationId: notification.id),
      );
    }

    // Navigate if action URL exists
    if (notification.actionUrl != null) {
      context.push(notification.actionUrl!);
    }
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will permanently delete all your notifications. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<NotificationBloc>().add(
                const ClearAllNotifications(userId: 'demo-user'),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.courseUpdate:
        return Icons.update;
      case NotificationType.newLesson:
        return Icons.book;
      case NotificationType.newAssignment:
        return Icons.assignment;
      case NotificationType.assignmentDue:
        return Icons.alarm;
      case NotificationType.assignmentGraded:
        return Icons.grade;
      case NotificationType.quizAvailable:
        return Icons.quiz;
      case NotificationType.quizGraded:
        return Icons.check_circle;
      case NotificationType.discussionReply:
        return Icons.chat_bubble;
      case NotificationType.discussionMention:
        return Icons.alternate_email;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.enrollment:
        return Icons.person_add;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.courseUpdate:
      case NotificationType.newLesson:
        return AppColors.info;
      case NotificationType.newAssignment:
      case NotificationType.assignmentDue:
        return AppColors.warning;
      case NotificationType.assignmentGraded:
      case NotificationType.quizGraded:
        return AppColors.success;
      case NotificationType.quizAvailable:
        return AppColors.primary;
      case NotificationType.discussionReply:
      case NotificationType.discussionMention:
        return AppColors.secondary;
      case NotificationType.announcement:
        return AppColors.warning;
      case NotificationType.enrollment:
        return AppColors.success;
      case NotificationType.general:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
