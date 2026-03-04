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
import '../../../lessons/data/repositories/lesson_repository.dart';
import '../../../lessons/presentation/widgets/course_syllabus_widget.dart';
import '../../../quizzes/data/models/models.dart';
import '../../../quizzes/data/repositories/quiz_repository.dart';
import '../../data/models/course_model.dart';
import '../bloc/course_bloc.dart';

/// Course detail screen showing course information and enrollment options
class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  void _loadCourse() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<CourseBloc>().add(
        CheckEnrollment(courseId: widget.courseId, userId: authState.user.id),
      );
    } else {
      context.read<CourseBloc>().add(LoadCourseDetail(widget.courseId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseEnrolled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Successfully enrolled in course!'),
                backgroundColor: AppColors.success,
              ),
            );
            _loadCourse();
          } else if (state is CourseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CourseLoading) {
            return const BitClassLoader(message: 'Loading course...');
          }

          if (state is CourseDetailLoaded) {
            return _CourseDetailContent(
              course: state.course,
              enrollment: state.enrollment,
            );
          }

          if (state is CourseError) {
            return ErrorState(message: state.message, onRetry: _loadCourse);
          }

          return const BitClassLoader();
        },
      ),
    );
  }
}

class _CourseDetailContent extends StatefulWidget {
  final CourseModel course;
  final EnrollmentModel? enrollment;

  const _CourseDetailContent({required this.course, this.enrollment});

  @override
  State<_CourseDetailContent> createState() => _CourseDetailContentState();
}

class _CourseDetailContentState extends State<_CourseDetailContent> {
  int _syllabusRefreshKey = 0;
  int _quizRefreshKey = 0;

  CourseModel get course => widget.course;
  EnrollmentModel? get enrollment => widget.enrollment;
  bool get isEnrolled => enrollment != null;

  void _refreshContent() {
    if (mounted) {
      setState(() {
        _syllabusRefreshKey++;
        _quizRefreshKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.role == 'instructor';
    final isOwnCourse =
        authState is AuthAuthenticated &&
        authState.user.id == course.instructorId;

    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.backgroundSecondary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.courses),
          ),
          actions: [
            if (isOwnCourse)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.push(AppRoutes.editCoursePath(course.id));
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: CourseBannerWidget(
              thumbnailUrl: course.thumbnailUrl,
              borderRadius: BorderRadius.zero,
              darkenOpacity: 0.3,
            ),
          ),
        ),

        // Content
        SliverPadding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  course.category,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(course.title, style: AppTextStyles.h1),
              const SizedBox(height: 16),

              // Stats row
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildStat(Icons.person_outline, course.instructorName),
                  _buildStat(
                    Icons.people_outline,
                    '${course.enrollmentCount} enrolled',
                  ),
                  _buildStat(
                    Icons.menu_book_outlined,
                    '${course.lessonCount} lessons',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Action button (students can enroll/continue; instructors see manage button for own courses)
              if (!isInstructor || isOwnCourse) _buildActionButton(context),
              const SizedBox(height: 32),

              // Description
              Text('About this course', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              GlowCard(
                glowColor: AppColors.primary,
                glowIntensity: 0.05,
                isHoverable: false,
                child: Text(
                  course.description,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
                ),
              ),
              const SizedBox(height: 32),

              // Course content (syllabus)
              Text('Course Content', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              _buildCourseSyllabus(),
              const SizedBox(height: 32),

              // Enrolled students (instructor's own course only)
              if (isOwnCourse) ...[
                _buildEnrolledStudentsSection(context),
                const SizedBox(height: 32),
                _buildInstructorContentSection(context),
                const SizedBox(height: 16),
                _buildManageAssignmentsLink(context),
                const SizedBox(height: 32),
              ],

              // Quizzes section (visible to enrolled students and course owner)
              if (isEnrolled || isOwnCourse) ...[
                Text(
                  isOwnCourse ? 'Manage Quizzes' : 'Quizzes',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 12),
                _CourseQuizzesSection(
                  key: ValueKey('quizzes-$_quizRefreshKey'),
                  courseId: course.id,
                ),
                _buildDiscussionsLink(context),
                const SizedBox(height: 32),
              ],

              // Progress (if enrolled)
              if (isEnrolled && !isInstructor) ...[
                Text('Your Progress', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                _buildProgressCard(),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    );
  }

  Widget _buildEnrolledStudentsSection(BuildContext context) {
    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.05,
      isHoverable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Enrolled Students', style: AppTextStyles.h3),
              const Spacer(),
              Text(
                '${course.enrollmentCount}',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'View and manage students enrolled in your course.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push(AppRoutes.courseStudentsPath(course.id));
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View All Students'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isOwnCourse =
        authState is AuthAuthenticated &&
        authState.user.id == course.instructorId;

    if (isEnrolled) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Navigate to first lesson if available
                try {
                  final lessons = await context
                      .read<LessonRepository>()
                      .getLessons(course.id);
                  if (lessons.isNotEmpty && context.mounted) {
                    context.push(
                      AppRoutes.lessonPath(course.id, lessons.first.id),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No lessons available yet')),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to load lessons')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continue Learning'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    // Instructor viewing own course — preview button
    if (isOwnCourse) {
      return ElevatedButton.icon(
        onPressed: () async {
          try {
            final lessons = await context.read<LessonRepository>().getLessons(
              course.id,
            );
            if (lessons.isNotEmpty && context.mounted) {
              context.push(AppRoutes.lessonPath(course.id, lessons.first.id));
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No lessons available yet')),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to load lessons')),
              );
            }
          }
        },
        icon: const Icon(Icons.visibility),
        label: const Text('Preview Course'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () {
        if (authState is AuthAuthenticated) {
          context.read<CourseBloc>().add(
            EnrollInCourse(
              courseId: course.id,
              userId: authState.user.id,
              studentName: authState.user.displayName,
              studentEmail: authState.user.email,
            ),
          );
        } else {
          context.go(AppRoutes.login);
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Enroll in Course'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildCourseSyllabus() {
    // Use the real CourseSyllabusWidget to show modules and lessons
    return CourseSyllabusWidget(
      key: ValueKey('syllabus-$_syllabusRefreshKey'),
      courseId: course.id,
      showHeader: true,
    );
  }

  Widget _buildInstructorContentSection(BuildContext context) {
    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.08,
      isHoverable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_circle_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Manage Content', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInstructorAction(
                context,
                icon: Icons.video_library_outlined,
                label: 'Add Lesson',
                color: AppColors.primary,
                onTap: () => context
                    .push('/courses/${course.id}/lessons/create')
                    .then((_) => _refreshContent()),
              ),
              _buildInstructorAction(
                context,
                icon: Icons.quiz_outlined,
                label: 'Add Quiz',
                color: AppColors.secondary,
                onTap: () => context
                    .push('/courses/${course.id}/quizzes/create')
                    .then((_) => _refreshContent()),
              ),
              _buildInstructorAction(
                context,
                icon: Icons.assignment_outlined,
                label: 'Add Assignment',
                color: AppColors.warning,
                onTap: () => context
                    .push('/courses/${course.id}/assignments/create')
                    .then((_) => _refreshContent()),
              ),
              _buildInstructorAction(
                context,
                icon: Icons.upload_file_outlined,
                label: 'Upload Files',
                color: AppColors.success,
                onTap: () => context
                    .push(AppRoutes.uploadFilePath(course.id))
                    .then((_) => _refreshContent()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = enrollment!.progress;
    final completedLessons = enrollment!.completedLessons;
    final totalLessons = enrollment!.totalLessons;

    return GlowCard(
      glowColor: progress >= 1.0 ? AppColors.success : AppColors.primary,
      glowIntensity: 0.1,
      isHoverable: false,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Progress', style: AppTextStyles.bodyMedium),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTextStyles.h4.copyWith(
                  color: progress >= 1.0
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completedLessons of $totalLessons lessons completed',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionsLink(BuildContext context) {
    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.08,
      onTap: () => context.push('/courses/${course.id}/discussions'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.forum_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Course Discussions', style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'Ask questions, share ideas, and collaborate',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildManageAssignmentsLink(BuildContext context) {
    return GlowCard(
      glowColor: AppColors.warning,
      glowIntensity: 0.08,
      onTap: () => context.push('/courses/${course.id}/assignments'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Assignments', style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'View assignments and manage submissions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Widget showing quizzes for a course
class _CourseQuizzesSection extends StatelessWidget {
  final String courseId;

  const _CourseQuizzesSection({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuizModel>>(
      future: context.read<QuizRepository>().getQuizzesByCourse(courseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return GlowCard(
            glowColor: AppColors.error,
            glowIntensity: 0.1,
            isHoverable: false,
            child: Text(
              'Error loading quizzes: ${snapshot.error}',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        final quizzes = snapshot.data ?? [];

        if (quizzes.isEmpty) {
          return GlowCard(
            glowColor: AppColors.primary,
            glowIntensity: 0.05,
            isHoverable: false,
            child: Row(
              children: [
                Icon(Icons.quiz_outlined, color: AppColors.textMuted, size: 32),
                const SizedBox(width: 12),
                Text(
                  'No quizzes available yet',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: quizzes
              .map((quiz) => _buildQuizCard(context, quiz))
              .toList(),
        );
      },
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowCard(
        glowColor: AppColors.secondary,
        glowIntensity: 0.08,
        onTap: () {
          context.push('/courses/$courseId/quizzes/${quiz.id}');
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.quiz_outlined,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz.totalPoints} pts',
                        style: AppTextStyles.bodySmall,
                      ),
                      if (quiz.timeLimitMinutes > 0) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${quiz.timeLimitMinutes}m',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${quiz.passingScore}% to pass',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
