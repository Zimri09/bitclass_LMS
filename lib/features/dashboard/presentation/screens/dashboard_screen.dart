import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../assignments/data/models/assignment_model.dart';
import '../../../assignments/data/repositories/assignment_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../../grades/data/repositories/grade_repository.dart';
import '../../../notifications/data/models/notification_model.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../cubit/dashboard_cubit.dart';

/// Dashboard screen showing overview and quick actions
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return BlocProvider(
              create: (_) =>
                  DashboardCubit(
                    courseRepository: context.read<CourseRepository>(),
                    assignmentRepository: context.read<AssignmentRepository>(),
                    gradeRepository: context.read<GradeRepository>(),
                    notificationRepository: context
                        .read<NotificationRepository>(),
                  )..loadDashboard(
                    userId: state.user.id,
                    isInstructor: state.user.role == 'instructor',
                  ),
              child: _DashboardContent(user: state.user),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final dynamic user;

  const _DashboardContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final isInstructor = user.role == 'instructor';

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, dashState) {
        return RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().refresh(
            userId: user.id,
            isInstructor: isInstructor,
          ),
          child: CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                floating: true,
                backgroundColor: AppColors.background,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: AppTextStyles.bodySmall),
                    Text(
                      user.displayNameOrEmail,
                      style: AppTextStyles.h3,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      context.push('/notifications');
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Content
              SliverPadding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Quick stats
                    _buildStatsRow(dashState, isInstructor),
                    const SizedBox(height: 32),

                    // Quick actions
                    Text('Quick Actions', style: AppTextStyles.h3),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, isInstructor),
                    const SizedBox(height: 32),

                    // Recent activity
                    Text('Recent Activity', style: AppTextStyles.h3),
                    const SizedBox(height: 16),
                    _buildRecentActivity(context, dashState),
                    const SizedBox(height: 32),

                    // Upcoming deadlines (for students)
                    if (!isInstructor) ...[
                      Text('Upcoming Deadlines', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      _buildUpcomingDeadlines(context, dashState),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(DashboardState dashState, bool isInstructor) {
    final isLoading =
        dashState.status == DashboardStatus.loading ||
        dashState.status == DashboardStatus.initial;

    final stats = isInstructor
        ? [
            _StatItem(
              icon: Icons.school,
              label: 'Courses',
              value: isLoading ? '...' : '${dashState.coursesTaughtCount}',
              color: AppColors.primary,
            ),
            _StatItem(
              icon: Icons.people,
              label: 'Students',
              value: isLoading ? '...' : '${dashState.totalStudents}',
              color: AppColors.secondary,
            ),
            _StatItem(
              icon: Icons.assignment,
              label: 'Pending',
              value: isLoading ? '...' : '${dashState.pendingSubmissions}',
              color: AppColors.warning,
            ),
          ]
        : [
            _StatItem(
              icon: Icons.bookmark,
              label: 'Enrolled',
              value: isLoading ? '...' : '${dashState.enrolledCount}',
              color: AppColors.primary,
            ),
            _StatItem(
              icon: Icons.check_circle,
              label: 'Completed',
              value: isLoading ? '...' : '${dashState.completedCount}',
              color: AppColors.success,
            ),
            _StatItem(
              icon: Icons.star,
              label: 'Avg Grade',
              value: isLoading ? '...' : dashState.averageGrade,
              color: AppColors.warning,
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;

        if (isNarrow) {
          return Column(
            children: stats
                .map(
                  (stat) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlowCard(
                      glowColor: stat.color,
                      glowIntensity: 0.15,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(stat.icon, color: stat.color, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat.label,
                                  style: AppTextStyles.bodySmall,
                                ),
                                Text(stat.value, style: AppTextStyles.h3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: stats
              .map(
                (stat) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GlowCard(
                      glowColor: stat.color,
                      glowIntensity: 0.15,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(stat.icon, color: stat.color, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            stat.value,
                            style: AppTextStyles.h2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            stat.label,
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isInstructor) {
    final actions = isInstructor
        ? [
            _QuickAction(
              icon: Icons.add_box,
              label: 'Create Course',
              color: AppColors.primary,
              onTap: () {
                context.push('/courses/create');
              },
            ),
            _QuickAction(
              icon: Icons.grading,
              label: 'Grade Submissions',
              color: AppColors.warning,
              onTap: () {
                context.push('/my-courses');
              },
            ),
            _QuickAction(
              icon: Icons.campaign,
              label: 'Announcement',
              color: AppColors.secondary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Announcements coming soon'),
                    backgroundColor: AppColors.info,
                  ),
                );
              },
            ),
          ]
        : [
            _QuickAction(
              icon: Icons.explore,
              label: 'Browse Courses',
              color: AppColors.primary,
              onTap: () {
                context.push('/courses');
              },
            ),
            _QuickAction(
              icon: Icons.play_circle,
              label: 'Continue Learning',
              color: AppColors.secondary,
              onTap: () {
                context.push('/enrolled-courses');
              },
            ),
            _QuickAction(
              icon: Icons.forum,
              label: 'Discussions',
              color: AppColors.info,
              onTap: () {
                context.push('/courses');
              },
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;

        if (isNarrow) {
          return Column(
            children: actions
                .map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlowCard(
                      glowColor: action.color,
                      glowIntensity: 0.1,
                      onTap: action.onTap,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: action.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              action.icon,
                              color: action.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              action.label,
                              style: AppTextStyles.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: actions
              .map(
                (action) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GlowCard(
                      glowColor: action.color,
                      glowIntensity: 0.1,
                      onTap: action.onTap,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: action.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(action.icon, color: action.color),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            action.label,
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentActivity(BuildContext context, DashboardState dashState) {
    if (dashState.status == DashboardStatus.loading ||
        dashState.status == DashboardStatus.initial) {
      return const GlowCard(
        glowColor: AppColors.primary,
        glowIntensity: 0.05,
        isHoverable: false,
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (dashState.recentActivity.isEmpty) {
      return GlowCard(
        glowColor: AppColors.primary,
        glowIntensity: 0.05,
        isHoverable: false,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.history, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your learning activities will appear here',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.05,
      isHoverable: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: dashState.recentActivity.map((notification) {
          return _buildActivityTile(context, notification);
        }).toList(),
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    NotificationModel notification,
  ) {
    final icon = switch (notification.type) {
      NotificationType.assignmentDue => Icons.assignment_late,
      NotificationType.quizGraded => Icons.quiz,
      NotificationType.discussionReply => Icons.forum,
      NotificationType.announcement => Icons.campaign,
      NotificationType.courseUpdate => Icons.school,
      _ => Icons.notifications,
    };

    final color = switch (notification.type) {
      NotificationType.assignmentDue => AppColors.warning,
      NotificationType.quizGraded => AppColors.success,
      NotificationType.discussionReply => AppColors.info,
      NotificationType.announcement => AppColors.secondary,
      _ => AppColors.primary,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        notification.title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Text(notification.body, style: AppTextStyles.bodySmall),
      trailing: Text(
        _formatTimeAgo(notification.createdAt),
        style: AppTextStyles.caption,
      ),
      onTap: notification.actionUrl != null
          ? () => context.push(notification.actionUrl!)
          : null,
    );
  }

  Widget _buildUpcomingDeadlines(
    BuildContext context,
    DashboardState dashState,
  ) {
    if (dashState.status == DashboardStatus.loading ||
        dashState.status == DashboardStatus.initial) {
      return const GlowCard(
        glowColor: AppColors.warning,
        glowIntensity: 0.05,
        isHoverable: false,
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (dashState.upcomingDeadlines.isEmpty) {
      return GlowCard(
        glowColor: AppColors.warning,
        glowIntensity: 0.05,
        isHoverable: false,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.event_available, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No upcoming deadlines',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your assignment deadlines will appear here',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return GlowCard(
      glowColor: AppColors.warning,
      glowIntensity: 0.05,
      isHoverable: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: dashState.upcomingDeadlines.map((assignment) {
          return _buildDeadlineTile(context, assignment);
        }).toList(),
      ),
    );
  }

  Widget _buildDeadlineTile(BuildContext context, AssignmentModel assignment) {
    final daysLeft = assignment.dueDate!.difference(DateTime.now()).inDays;
    final urgencyColor = daysLeft <= 1
        ? AppColors.error
        : daysLeft <= 3
        ? AppColors.warning
        : AppColors.textSecondary;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: urgencyColor.withValues(alpha: 0.15),
        child: Icon(Icons.assignment, color: urgencyColor, size: 20),
      ),
      title: Text(assignment.title, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        'Due ${DateFormat.MMMd().add_jm().format(assignment.dueDate!)}',
        style: AppTextStyles.bodySmall,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: urgencyColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          daysLeft == 0
              ? 'Today'
              : daysLeft == 1
              ? '1 day'
              : '$daysLeft days',
          style: AppTextStyles.caption.copyWith(color: urgencyColor),
        ),
      ),
      onTap: () {
        context.push(
          '/courses/${assignment.courseId}/assignments/${assignment.id}',
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dateTime);
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
