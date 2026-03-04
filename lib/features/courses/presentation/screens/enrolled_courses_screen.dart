import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/course_banner.dart';
import '../../../../shared/widgets/glow_card.dart';
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
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadEnrollments,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: Text('My Learning', style: AppTextStyles.h3),
              actions: [
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.courses),
                  icon: const Icon(Icons.explore),
                  label: const Text('Browse'),
                ),
                const SizedBox(width: 16),
              ],
            ),

            // Stats summary
            if (_enrolledCourses != null && _enrolledCourses!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                    16,
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                    0,
                  ),
                  child: _buildStatsSummary(),
                ),
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
                  title: 'No courses yet',
                  subtitle: 'Browse our catalog and enroll in a course',
                  action: ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.courses),
                    icon: const Icon(Icons.explore),
                    label: const Text('Browse Courses'),
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

  Widget _buildStatsSummary() {
    final total = _enrolledCourses!.length;
    final completed = _enrolledCourses!
        .where((c) => c.enrollment.isCompleted)
        .length;
    final inProgress = total - completed;
    final avgProgress = _enrolledCourses!.isEmpty
        ? 0.0
        : _enrolledCourses!
                  .map((c) => c.enrollment.progress)
                  .reduce((a, b) => a + b) /
              total;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stats = [
          _buildStatCard(
            'Enrolled',
            '$total',
            Icons.bookmark,
            AppColors.primary,
          ),
          _buildStatCard(
            'In Progress',
            '$inProgress',
            Icons.play_circle,
            AppColors.info,
          ),
          _buildStatCard(
            'Completed',
            '$completed',
            Icons.check_circle,
            AppColors.success,
          ),
          _buildStatCard(
            'Avg Progress',
            '${(avgProgress * 100).toInt()}%',
            Icons.trending_up,
            AppColors.secondary,
          ),
        ];

        if (constraints.maxWidth < 400) {
          // 2x2 grid on narrow screens
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: stats[0]),
                  const SizedBox(width: 8),
                  Expanded(child: stats[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: stats[2]),
                  const SizedBox(width: 8),
                  Expanded(child: stats[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: stats[0]),
            const SizedBox(width: 12),
            Expanded(child: stats[1]),
            const SizedBox(width: 12),
            Expanded(child: stats[2]),
            const SizedBox(width: 12),
            Expanded(child: stats[3]),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: GlowCard(
        glowColor: color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.h3),
            Text(label, style: AppTextStyles.caption),
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
    final enrollment = data.enrollment;
    final isCompleted = enrollment.isCompleted;

    return GlowCard(
      glowColor: isCompleted ? AppColors.success : AppColors.primary,
      glowIntensity: 0.1,
      onTap: () => context.go(AppRoutes.courseDetailPath(course.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              CourseBannerWidget(
                thumbnailUrl: course.thumbnailUrl,
                width: 100,
                height: 75,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course.category,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Completed',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.title,
                      style: AppTextStyles.h4,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(course.instructorName, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),

              // Continue button
              IconButton(
                onPressed: () {
                  context.go(AppRoutes.courseDetailPath(course.id));
                },
                icon: Icon(
                  isCompleted ? Icons.replay : Icons.play_arrow,
                  color: isCompleted ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${enrollment.completedLessons} of ${enrollment.totalLessons} lessons',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    '${enrollment.progressPercent}%',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: enrollment.progress,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? AppColors.success : AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
