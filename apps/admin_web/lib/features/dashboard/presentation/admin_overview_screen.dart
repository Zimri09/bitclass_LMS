import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_page.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

class AdminOverviewScreen extends StatefulWidget {
  final AdminRepository repository;

  const AdminOverviewScreen({super.key, required this.repository});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  late Future<AdminDashboardSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.fetchOverview();
  }

  void _refresh() {
    setState(() => _snapshot = widget.repository.fetchOverview());
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Overview',
      description: 'A live summary of the BitClass learning community.',
      action: OutlinedButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh, size: 19),
        label: const Text('Refresh'),
      ),
      child: FutureBuilder<AdminDashboardSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return AdminErrorPanel(
              message: 'Dashboard data could not be loaded.',
              onRetry: _refresh,
            );
          }

          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricGrid(data: data),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final panels = [
                    _RecentUsersPanel(users: data.recentUsers),
                    _RecentCoursesPanel(courses: data.recentCourses),
                  ];
                  if (constraints.maxWidth >= 980) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: panels[0]),
                        const SizedBox(width: 20),
                        Expanded(child: panels[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      panels[0],
                      const SizedBox(height: 20),
                      panels[1],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final AdminDashboardSnapshot data;

  const _MetricGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        label: 'Total users',
        value: data.userCount,
        icon: Icons.group_outlined,
        color: AdminColors.primary,
      ),
      _Metric(
        label: 'Courses',
        value: data.courseCount,
        icon: Icons.menu_book_outlined,
        color: AdminColors.secondary,
      ),
      _Metric(
        label: 'Enrollments',
        value: data.enrollmentCount,
        icon: Icons.how_to_reg_outlined,
        color: AdminColors.warning,
      ),
      _Metric(
        label: 'Submissions',
        value: data.submissionCount,
        icon: Icons.assignment_turned_in_outlined,
        color: const Color(0xFF9B7EDE),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final spacing = 16.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(metric.icon, color: metric.color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(metric.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentUsersPanel extends StatelessWidget {
  final List<AdminAccount> users;

  const _RecentUsersPanel({required this.users});

  @override
  Widget build(BuildContext context) {
    return _OverviewPanel(
      title: 'Recently joined',
      actionLabel: 'View users',
      onAction: () => context.go('/users'),
      child: users.isEmpty
          ? const _CompactEmpty(message: 'No users yet.')
          : Column(
              children: [
                for (var index = 0; index < users.length; index++) ...[
                  _UserRow(user: users[index]),
                  if (index != users.length - 1) const Divider(),
                ],
              ],
            ),
    );
  }
}

class _RecentCoursesPanel extends StatelessWidget {
  final List<AdminCourse> courses;

  const _RecentCoursesPanel({required this.courses});

  @override
  Widget build(BuildContext context) {
    return _OverviewPanel(
      title: 'Recent courses',
      actionLabel: 'View courses',
      onAction: () => context.go('/courses'),
      child: courses.isEmpty
          ? const _CompactEmpty(message: 'No courses yet.')
          : Column(
              children: [
                for (var index = 0; index < courses.length; index++) ...[
                  _CourseRow(course: courses[index]),
                  if (index != courses.length - 1) const Divider(),
                ],
              ],
            ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  const _OverviewPanel({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminAccount user;

  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.primarySoft,
            foregroundColor: AdminColors.primary,
            child: Text(user.displayName.substring(0, 1).toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          AdminStatusChip(label: user.role, color: _roleColor(user.role)),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final AdminCourse course;

  const _CourseRow({required this.course});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AdminColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 21,
              color: AdminColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  course.instructorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          AdminStatusChip(
            label: course.isPublished ? 'Published' : 'Draft',
            color: course.isPublished
                ? AdminColors.success
                : AdminColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  final String message;

  const _CompactEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(message)),
    );
  }
}

class _Metric {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

Color _roleColor(String role) {
  return switch (role) {
    'admin' => const Color(0xFF9B7EDE),
    'instructor' => AdminColors.primary,
    _ => AdminColors.secondary,
  };
}
