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
        authState is AuthAuthenticated && authState.user.isStaff;
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

class NotificationSettingsView extends StatefulWidget {
  final String userId;
  final bool isInstructor;

  const NotificationSettingsView({
    super.key,
    required this.userId,
    required this.isInstructor,
  });

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  NotificationSettings? _lastSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: SafeArea(
        top: false,
        child: BlocConsumer<NotificationBloc, NotificationState>(
          listener: (context, state) {
            if (state is NotificationSettingsLoaded) {
              _lastSettings = state.settings;
            } else if (state is NotificationSettingsUpdated) {
              _lastSettings = state.settings;
            } else if (state is NotificationError && _lastSettings != null) {
              final messenger = ScaffoldMessenger.of(context);
              messenger
                ..clearSnackBars()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          builder: (context, state) {
            final stateSettings = switch (state) {
              NotificationSettingsLoaded(:final settings) => settings,
              NotificationSettingsUpdated(:final settings) => settings,
              _ => null,
            };
            final settings = stateSettings ?? _lastSettings;

            if (settings != null) {
              return _buildSettings(context, settings);
            }

            if (state is NotificationSettingsLoading) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is NotificationError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          context.read<NotificationBloc>().add(
                            LoadNotificationSettings(userId: widget.userId),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
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
              title: Text(
                'Enable Push Notifications',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Receive course updates on this device',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: settings.pushEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (value) {
                context.read<NotificationBloc>().add(
                  TogglePushNotifications(
                    userId: widget.userId,
                    enabled: value,
                  ),
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
                if (widget.isInstructor) ...[
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.enrollment,
                    Icons.person_add,
                    'Enrollments',
                    'When a student joins one of your courses',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.assignmentSubmitted,
                    Icons.assignment_turned_in,
                    'Activity submissions',
                    'New student work that is ready for review',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.quizSubmitted,
                    Icons.fact_check,
                    'Quiz submissions',
                    'When a student completes a quiz attempt',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.discussionActivity,
                    Icons.forum,
                    'Student discussions',
                    'New discussion threads created in your courses',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.discussionReply,
                    Icons.reply,
                    'Replies',
                    'Replies to your own discussions and comments',
                  ),
                ] else ...[
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.newLesson,
                    Icons.book,
                    'New Lessons',
                    'When new content is added to your courses',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.newAssignment,
                    Icons.assignment,
                    'Activities',
                    'New activities and due date reminders',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.assignmentGraded,
                    Icons.grade,
                    'Grades',
                    'When your activity work is graded',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.quizAvailable,
                    Icons.quiz,
                    'Quizzes',
                    'Quiz availability and results',
                  ),
                  _buildDivider(),
                  _buildTypeToggle(
                    context,
                    settings,
                    NotificationType.discussionReply,
                    Icons.chat_bubble,
                    'Discussions',
                    'Replies to your posts and mentions',
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
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        _buildSection(
          title: 'Quiet Hours',
          subtitle: 'Pause notifications during certain hours',
          child: Card(
            color: AppColors.surface,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Enable Quiet Hours',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    '${_formatHour(settings.quietHoursStart)} - '
                    '${_formatHour(settings.quietHoursEnd)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: settings.quietHoursEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) {
                    context.read<NotificationBloc>().add(
                      UpdateQuietHours(
                        userId: widget.userId,
                        enabled: value,
                        startHour: settings.quietHoursStart,
                        endHour: settings.quietHoursEnd,
                      ),
                    );
                  },
                ),
                if (settings.quietHoursEnabled) ...[
                  _buildDivider(),
                  ListTile(
                    title: const Text('Starts'),
                    trailing: Text(_formatHour(settings.quietHoursStart)),
                    onTap: () =>
                        _pickQuietHour(context, settings, isStart: true),
                  ),
                  _buildDivider(),
                  ListTile(
                    title: const Text('Ends'),
                    trailing: Text(_formatHour(settings.quietHoursEnd)),
                    onTap: () =>
                        _pickQuietHour(context, settings, isStart: false),
                  ),
                ],
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
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Preferences sync to all of your registered devices. '
                  'Android system permission can also be changed in device settings.',
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
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Switch(
        value: settings.isTypeEnabled(type),
        activeThumbColor: AppColors.primary,
        onChanged: settings.pushEnabled
            ? (value) {
                context.read<NotificationBloc>().add(
                  ToggleNotificationType(
                    userId: widget.userId,
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
    return Divider(color: AppColors.surfaceLight, height: 1, indent: 72);
  }

  String _formatHour(int hour) {
    final normalized = hour % 24;
    final period = normalized >= 12 ? 'PM' : 'AM';
    final displayHour = normalized % 12 == 0 ? 12 : normalized % 12;
    return '$displayHour:00 $period';
  }

  Future<void> _pickQuietHour(
    BuildContext context,
    NotificationSettings settings, {
    required bool isStart,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: isStart ? settings.quietHoursStart : settings.quietHoursEnd,
        minute: 0,
      ),
    );
    if (selected == null || !context.mounted) {
      return;
    }

    context.read<NotificationBloc>().add(
      UpdateQuietHours(
        userId: widget.userId,
        enabled: settings.quietHoursEnabled,
        startHour: isStart ? selected.hour : settings.quietHoursStart,
        endHour: isStart ? settings.quietHoursEnd : selected.hour,
      ),
    );
  }
}
