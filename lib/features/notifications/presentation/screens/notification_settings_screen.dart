import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/notification_repository.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

/// Screen for managing notification settings
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  String _currentUserId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return 'demo-user-1';
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId(context);
    final authState = context.read<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.role == 'instructor';
    return BlocProvider(
      create: (context) => NotificationBloc(
        notificationRepository: context.read<NotificationRepository>(),
      )..add(LoadNotificationSettings(userId: userId)),
      child: NotificationSettingsView(
        userId: userId,
        isInstructor: isInstructor,
      ),
    );
  }
}

class NotificationSettingsView extends StatelessWidget {
  final String userId;
  final bool isInstructor;

  const NotificationSettingsView({
    super.key,
    required this.userId,
    required this.isInstructor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          if (state is NotificationSettingsUpdated) {
            // Reload settings to refresh UI
            context.read<NotificationBloc>().add(
              LoadNotificationSettings(userId: userId),
            );
          }
        },
        builder: (context, state) {
          if (state is NotificationSettingsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
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
                  ),
                ],
              ),
            );
          }

          if (state is NotificationSettingsLoaded) {
            return _buildSettings(context, state.settings);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSettings(BuildContext context, NotificationSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Master toggle
        _buildSection(
          title: 'Push Notifications',
          child: Card(
            color: AppColors.surface,
            child: SwitchListTile(
              title: const Text(
                'Enable Push Notifications',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Receive notifications on your device',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: settings.pushEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (value) {
                context.read<NotificationBloc>().add(
                  TogglePushNotifications(userId: userId, enabled: value),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Notification types
        _buildSection(
          title: 'Notification Types',
          subtitle: 'Choose which notifications you want to receive',
          child: Card(
            color: AppColors.surface,
            child: Column(
              children: [
                _buildTypeToggle(
                  context,
                  settings,
                  NotificationType.newLesson,
                  Icons.book,
                  isInstructor ? 'Lesson Updates' : 'New Lessons',
                  isInstructor
                      ? 'When lesson/content changes happen in your courses'
                      : 'When new content is added to your courses',
                ),
                _buildDivider(),
                _buildTypeToggle(
                  context,
                  settings,
                  NotificationType.newAssignment,
                  Icons.assignment,
                  isInstructor ? 'Submissions' : 'Assignments',
                  isInstructor
                      ? 'New assignment submissions that need review'
                      : 'New assignments and due date reminders',
                ),
                _buildDivider(),
                _buildTypeToggle(
                  context,
                  settings,
                  NotificationType.assignmentGraded,
                  Icons.grade,
                  isInstructor ? 'Submission Reviews' : 'Grades',
                  isInstructor
                      ? 'Status updates while grading student work'
                      : 'When your work is graded',
                ),
                _buildDivider(),
                _buildTypeToggle(
                  context,
                  settings,
                  NotificationType.quizAvailable,
                  Icons.quiz,
                  isInstructor ? 'Quiz Activity' : 'Quizzes',
                  isInstructor
                      ? 'Quiz publishing and learner activity updates'
                      : 'Quiz availability and results',
                ),
                _buildDivider(),
                _buildTypeToggle(
                  context,
                  settings,
                  NotificationType.discussionReply,
                  Icons.chat_bubble,
                  'Discussions',
                  isInstructor
                      ? 'Replies, mentions, and student questions'
                      : 'Replies to your posts and mentions',
                ),
                _buildDivider(),
                _buildTypeToggle(
                  context,
                  settings,
                  NotificationType.announcement,
                  Icons.campaign,
                  'Announcements',
                  'Important course announcements',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Quiet hours (UI only for demo)
        _buildSection(
          title: 'Quiet Hours',
          subtitle: 'Pause notifications during certain hours',
          child: Card(
            color: AppColors.surface,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Enable Quiet Hours',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    '10:00 PM - 8:00 AM',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: settings.quietHoursEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) {
                    // In a full implementation, this would update quiet hours
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quiet hours settings coming soon'),
                        backgroundColor: AppColors.info,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Info note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Push notifications require FCM to be configured. This demo shows the settings UI.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildTypeToggle(
    BuildContext context,
    NotificationSettings settings,
    NotificationType type,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Switch(
        value: settings.isTypeEnabled(type),
        activeThumbColor: AppColors.primary,
        onChanged: settings.pushEnabled
            ? (value) {
                context.read<NotificationBloc>().add(
                  ToggleNotificationType(
                    userId: userId,
                    type: type,
                    enabled: value,
                  ),
                );
              }
            : null,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: AppColors.surfaceLight, height: 1, indent: 72);
  }
}
