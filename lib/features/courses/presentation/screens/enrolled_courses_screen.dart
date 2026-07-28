import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
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
                  onPressed: () => context.go(AppRoutes.courses),
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
                    onPressed: () => context.go(AppRoutes.courses),
                    icon: Icon(Icons.explore),
                    label: const Text('Join a Class'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _EnrolledCourseCard(
                        data: _enrolledCourses![index],
                      ),
                    ),
                    childCount: _enrolledCourses!.length,
                  ),
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

  const _EnrolledCourseCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final course = data.course;

    return ClassroomCourseCard(
      course: course,
      subtitle: '${data.enrollment.completedLessons} of ${data.enrollment.totalLessons} lessons complete',
      statusLabel: data.enrollment.progress >= 1 ? 'Completed' : 'In progress',
      statusColor: data.enrollment.progress >= 1
          ? AppColors.success
          : AppColors.primary,
      onTap: () => context.go(AppRoutes.courseDetailPath(course.id)),
      footer: [
        Icon(Icons.play_circle_outline, size: 20, color: AppColors.primary),
      ],
    );
  }
}
