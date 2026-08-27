import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/classroom_course_card.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';

/// Screen showing student's enrolled courses
class EnrolledCoursesScreen extends StatefulWidget {
  const EnrolledCoursesScreen({super.key});

  @override
  State<EnrolledCoursesScreen> createState() => _EnrolledCoursesScreenState();
}

class _EnrolledCoursesScreenState extends State<EnrolledCoursesScreen> {
  List<_EnrolledCourseData>? _enrolledCourses;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final repo = context.read<CourseRepository>();
        final enrollments = await repo.getUserEnrollments(authState.user.id);

        final enrolledCourses = <_EnrolledCourseData>[];
        for (final enrollment in enrollments) {
          final course = await repo.getCourse(enrollment.courseId);
          if (course != null) {
            enrolledCourses.add(
              _EnrolledCourseData(course: course, enrollment: enrollment),
            );
          }
        }

        setState(() {
          _enrolledCourses = enrolledCourses;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadEnrollments,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              title: Text('Classes', style: AppTextStyles.h3),
              actions: [
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.courses),
                  icon: Icon(Icons.explore),
                  label: const Text('Browse'),
                ),
                const SizedBox(width: 16),
              ],
            ),

            // Content
            if (_isLoading)
              const SliverCourseGridSkeleton()
            else if (_error != null)
              SliverFillRemaining(
                child: ErrorState(message: _error!, onRetry: _loadEnrollments),
              )
            else if (_enrolledCourses == null || _enrolledCourses!.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.bookmark_outline,
                  title: 'No classes yet',
                  subtitle: 'Join a class with the code from your instructor',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.courses),
                    icon: Icon(Icons.explore),
                    label: const Text('Join a Class'),
                  ),
                ),
              )
            else
              SliverClassroomCourseLayout(
                itemCount: _enrolledCourses!.length,
                itemBuilder: (context, index) => _EnrolledCourseCard(
                  data: _enrolledCourses![index],
                  onUnenrolled: _loadEnrollments,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnrolledCourseData {
  final CourseModel course;
  final EnrollmentModel enrollment;

  _EnrolledCourseData({required this.course, required this.enrollment});
}

class _EnrolledCourseCard extends StatelessWidget {
  final _EnrolledCourseData data;
  final Future<void> Function() onUnenrolled;

  const _EnrolledCourseCard({required this.data, required this.onUnenrolled});

  @override
  Widget build(BuildContext context) {
    final course = data.course;

    return ClassroomCourseCard(
      course: course,
      statusLabel: data.enrollment.progress >= 1 ? 'Completed' : 'In progress',
      statusColor: data.enrollment.progress >= 1
          ? AppColors.success
          : AppColors.primary,
      onTap: () => context.push(AppRoutes.courseDetailPath(course.id)),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        tooltip: 'Class options',
        onPressed: () => _showClassOptions(context),
      ),
      footer: [
        Icon(Icons.play_circle_outline, size: 20, color: AppColors.primary),
      ],
    );
  }

  void _showClassOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        leading: Icon(Icons.exit_to_app, color: AppColors.error),
        title: Text(
          'Unenroll',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error),
        ),
        onTap: () {
          Navigator.pop(sheetContext);
          _confirmUnenroll(context);
        },
      ),
    );
  }

  Future<void> _confirmUnenroll(BuildContext context) async {
    final course = data.course;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unenroll from class?'),
        content: Text(
          'You will lose access to "${course.title}" and its course content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Unenroll'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<CourseRepository>().unenrollFromCourse(course.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unenrolled from ${course.title}'),
          backgroundColor: AppColors.success,
        ),
      );
      await onUnenrolled();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
