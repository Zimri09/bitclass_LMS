import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/course_banner.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../assignments/presentation/screens/assignment_list_screen.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../class_records/presentation/screens/course_records_screen.dart';
import '../../../discussions/presentation/screens/channel_list_screen.dart';
import '../../../lessons/data/repositories/lesson_repository.dart';
import '../../../lessons/presentation/widgets/course_syllabus_widget.dart';
import '../../../quizzes/data/models/models.dart';
import '../../../quizzes/data/repositories/quiz_repository.dart';
import '../../../quizzes/presentation/widgets/quiz_delete_button.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';
import '../bloc/course_bloc.dart';

/// Course detail screen showing course information and enrollment options
class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  int _selectedTab = 0;

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
      body: BlocConsumer<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseUpdated) {
            // Course was just edited (e.g. via the Edit Course screen, which
            // is pushed on top of this screen and shares this CourseBloc) or
            // published/unpublished via the toggle below. Without this,
            // the state stays on CourseUpdated forever and the builder below
            // falls through to its default loading indicator.
            final isPublished = state.course.isPublished;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isPublished
                      ? 'Course published successfully!'
                      : 'Course unpublished successfully!',
                ),
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
            return StreamBuilder<CourseModel?>(
              stream: context.read<CourseRepository>().watchCourse(
                state.course.id,
              ),
              initialData: state.course,
              builder: (context, snapshot) => _CourseDetailContent(
                course: snapshot.data ?? state.course,
                enrollment: state.enrollment,
                selectedTab: _selectedTab,
              ),
            );
          }

          if (state is CourseError) {
            return ErrorState(message: state.message, onRetry: _loadCourse);
          }

          return const BitClassLoader();
        },
      ),
      bottomNavigationBar: BlocBuilder<CourseBloc, CourseState>(
        builder: (context, state) {
          final authState = context.watch<AuthBloc>().state;
          final isOwnCourse =
              state is CourseDetailLoaded &&
              authState is AuthAuthenticated &&
              authState.user.id == state.course.instructorId;
          return NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              setState(() => _selectedTab = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Content',
              ),
              const NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'Work',
              ),
              const NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: 'Discussion',
              ),
              NavigationDestination(
                icon: Icon(
                  isOwnCourse
                      ? Icons.table_chart_outlined
                      : Icons.fact_check_outlined,
                ),
                selectedIcon: Icon(
                  isOwnCourse ? Icons.table_chart : Icons.fact_check,
                ),
                label: isOwnCourse ? 'Records' : 'Attendance',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'People',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CourseDetailContent extends StatefulWidget {
  final CourseModel course;
  final EnrollmentModel? enrollment;
  final int selectedTab;

  const _CourseDetailContent({
    required this.course,
    this.enrollment,
    required this.selectedTab,
  });

  @override
  State<_CourseDetailContent> createState() => _CourseDetailContentState();
}

class _CourseDetailContentState extends State<_CourseDetailContent> {
  int _syllabusRefreshKey = 0;
  bool _isUnenrolling = false;

  CourseModel get course => widget.course;
  EnrollmentModel? get enrollment => widget.enrollment;
  bool get isEnrolled => enrollment != null;

  void _refreshContent() {
    if (mounted) {
      setState(() {
        _syllabusRefreshKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.role == 'instructor';
    final isStudent =
        authState is AuthAuthenticated && authState.user.role == 'student';
    final isOwnCourse =
        authState is AuthAuthenticated &&
        authState.user.id == course.instructorId;
    final studentCourseMenu = isStudent && isEnrolled
        ? _buildStudentCourseMenu(context)
        : null;

    if (widget.selectedTab == 1) {
      return SafeArea(
        bottom: false,
        child: _CourseWorkTab(
          course: course,
          isCourseOwner: isOwnCourse,
          courseMenu: studentCourseMenu,
        ),
      );
    }
    if (widget.selectedTab == 2) {
      return SafeArea(
        bottom: false,
        child: _CourseDiscussionTab(
          courseId: course.id,
          courseMenu: studentCourseMenu,
        ),
      );
    }
    if (widget.selectedTab == 3) {
      if (authState is! AuthAuthenticated) {
        return const BitClassLoader();
      }
      return SafeArea(
        bottom: false,
        child: isOwnCourse
            ? CourseRecordsScreen(
                course: course,
                currentUserId: authState.user.id,
              )
            : AttendanceScreen(
                course: course,
                isCourseOwner: false,
                currentUserId: authState.user.id,
                courseMenu: studentCourseMenu,
              ),
      );
    }
    if (widget.selectedTab == 4) {
      return SafeArea(
        bottom: false,
        child: _CoursePeopleTab(course: course, courseMenu: studentCourseMenu),
      );
    }

    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              final authState = context.read<AuthBloc>().state;
              context.go(
                authState is AuthAuthenticated &&
                        authState.user.role == 'instructor'
                    ? AppRoutes.myCourses
                    : AppRoutes.dashboard,
              );
            },
          ),
          actions: [
            if (isOwnCourse)
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  context.push(AppRoutes.editCoursePath(course.id));
                },
              ),
            if (studentCourseMenu != null)
              _buildStudentCourseMenu(context, iconColor: Colors.white),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                CourseBannerWidget(
                  thumbnailUrl: course.thumbnailUrl,
                  borderRadius: BorderRadius.zero,
                  darkenOpacity: 0.38,
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 18,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            course.instructorAvatarUrl?.isNotEmpty == true
                            ? NetworkImage(course.instructorAvatarUrl!)
                            : null,
                        child: course.instructorAvatarUrl?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.school_outlined),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          course.instructorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

              // Program
              Text('Course Program', style: AppTextStyles.h3),
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
              const SizedBox(height: 16),
              _buildCourseMaterialsLink(context),
              const SizedBox(height: 32),

              // Course setup and content controls stay with the content tab.
              if (isOwnCourse) ...[
                _buildPublishToggleCard(context),
                const SizedBox(height: 16),
                _buildCourseCodeCard(context),
                const SizedBox(height: 24),
                _buildInstructorContentSection(context),
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

  /// Publish / Unpublish toggle card for the course owner
  Widget _buildPublishToggleCard(BuildContext context) {
    final isPublished = course.isPublished;
    final statusColor = isPublished ? AppColors.success : AppColors.warning;
    final statusLabel = isPublished ? 'Published' : 'Draft';
    final statusIcon = isPublished ? Icons.public : Icons.lock_outline;

    return GlowCard(
      glowColor: statusColor,
      glowIntensity: 0.12,
      isHoverable: false,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.12),
              statusColor.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: statusColor.withOpacity(0.35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Status text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Course Status', style: AppTextStyles.h4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPublished
                        ? 'Visible to students in Browse Courses'
                        : 'Hidden from students — publish to make it live',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle switch
            BlocBuilder<CourseBloc, CourseState>(
              builder: (context, state) {
                final isLoading = state is CourseLoading;
                return isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: statusColor,
                          ),
                        ),
                      )
                    : Switch(
                        value: isPublished,
                        activeColor: AppColors.success,
                        inactiveThumbColor: AppColors.warning,
                        inactiveTrackColor: AppColors.warning.withOpacity(0.3),
                        onChanged: (newValue) async {
                          // Confirm before toggling
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                newValue
                                    ? 'Publish Course?'
                                    : 'Unpublish Course?',
                                style: AppTextStyles.h3,
                              ),
                              content: Text(
                                newValue
                                    ? 'This will make the course visible to all students in Browse Courses.'
                                    : 'This will hide the course from students. Enrolled students will still have access.',
                                style: AppTextStyles.bodyMedium,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: newValue
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  child: Text(
                                    newValue ? 'Publish' : 'Unpublish',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            context.read<CourseBloc>().add(
                              ToggleCoursePublish(
                                courseId: course.id,
                                publish: newValue,
                              ),
                            );
                          }
                        },
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Card showing the shareable course code for instructors
  Widget _buildCourseCodeCard(BuildContext context) {
    final code = course.courseCode.isNotEmpty ? course.courseCode : '------';
    return GlowCard(
      glowColor: AppColors.secondary,
      glowIntensity: 0.15,
      isHoverable: false,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withOpacity(0.15),
              AppColors.primary.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Course Join Code', style: AppTextStyles.h4),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy_rounded, color: AppColors.secondary),
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Code copied to clipboard!',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // The code displayed large
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(
                  letterSpacing: 12,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Share this code with students so they can join from the Browse Courses tab',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
              Icon(Icons.people, color: AppColors.primary, size: 22),
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
              icon: Icon(Icons.visibility),
              label: const Text('View All Students'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppColors.primary),
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
              icon: Icon(Icons.play_arrow),
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
        icon: Icon(Icons.visibility),
        label: const Text('Preview Course'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => context.push(AppRoutes.courses),
      icon: const Icon(Icons.vpn_key_rounded),
      label: const Text('Join with Course Code'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildCourseSyllabus() {
    final authState = context.read<AuthBloc>().state;
    final isCourseOwner =
        authState is AuthAuthenticated &&
        authState.user.id == course.instructorId;

    return CourseSyllabusWidget(
      key: ValueKey('syllabus-$_syllabusRefreshKey'),
      courseId: course.id,
      showHeader: true,
      showStudentProgress: !isCourseOwner,
    );
  }

  Widget _buildStudentCourseMenu(BuildContext context, {Color? iconColor}) {
    if (_isUnenrolling) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: iconColor ?? AppColors.primary,
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      tooltip: 'Course options',
      onSelected: (value) {
        if (value == 'unenroll') {
          _confirmUnenroll();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'unenroll',
          child: Row(
            children: [
              Icon(Icons.exit_to_app, size: 20, color: AppColors.error),
              const SizedBox(width: 10),
              Text('Unenroll Course', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUnenroll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unenroll from course?'),
        content: Text(
          'Are you sure you want to unenroll from "${course.title}"? '
          'You will lose access to course materials, and your saved lesson '
          'progress will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Unenroll Course'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isUnenrolling = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<CourseRepository>().unenrollFromCourse(course.id);
      if (!mounted) {
        return;
      }

      context.go(AppRoutes.dashboard);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('You have successfully unenrolled from the course.'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isUnenrolling = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(userFriendlyErrorMessage(error)),
            backgroundColor: AppColors.error,
          ),
        );
    }
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
              Icon(
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
                icon: Icons.folder_copy_outlined,
                label: 'Course materials',
                color: AppColors.success,
                onTap: () => context
                    .push(AppRoutes.filesPath(course.id))
                    .then((_) => _refreshContent()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseMaterialsLink(BuildContext context) {
    return GlowCard(
      glowColor: AppColors.success,
      glowIntensity: 0.06,
      onTap: () => context.push(AppRoutes.filesPath(course.id)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_outlined, color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Learning materials', style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'Open uploaded files and additional course resources.',
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
    return _StudentCourseProgressCard(
      courseId: course.id,
      enrollmentId: enrollment!.id,
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
            child: Icon(Icons.assignment_outlined, color: AppColors.warning),
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
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _CourseWorkTab extends StatelessWidget {
  final CourseModel course;
  final bool isCourseOwner;
  final Widget? courseMenu;

  const _CourseWorkTab({
    required this.course,
    required this.isCourseOwner,
    this.courseMenu,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Quizzes & Assignments', style: AppTextStyles.h3),
                ),
                if (isCourseOwner)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add course work',
                    onSelected: (value) {
                      if (value == 'quiz') {
                        context.push('/courses/${course.id}/quizzes/create');
                      } else {
                        context.push(AppRoutes.createAssignmentPath(course.id));
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'quiz', child: Text('Add quiz')),
                      PopupMenuItem(
                        value: 'assignment',
                        child: Text('Add assignment'),
                      ),
                    ],
                  ),
                ?courseMenu,
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Quizzes'),
              Tab(text: 'Assignments'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _CourseQuizzesSection(
                    courseId: course.id,
                    canManage: isCourseOwner,
                  ),
                ),
                AssignmentListScreen(courseId: course.id, embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseDiscussionTab extends StatelessWidget {
  final String courseId;
  final Widget? courseMenu;

  const _CourseDiscussionTab({required this.courseId, this.courseMenu});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Course Discussion', style: AppTextStyles.h3),
              ),
              ?courseMenu,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Announcements, questions, and class conversations.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: ChannelListScreen(courseId: courseId, embedded: true)),
      ],
    );
  }
}

class _CoursePeopleTab extends StatefulWidget {
  final CourseModel course;
  final Widget? courseMenu;

  const _CoursePeopleTab({required this.course, this.courseMenu});

  @override
  State<_CoursePeopleTab> createState() => _CoursePeopleTabState();
}

class _CoursePeopleTabState extends State<_CoursePeopleTab> {
  late Future<List<CourseRosterMember>> _students;

  @override
  void initState() {
    super.initState();
    _students = _loadStudents();
  }

  Future<List<CourseRosterMember>> _loadStudents() {
    return context.read<CourseRepository>().getCourseRoster(widget.course.id);
  }

  Future<void> _refresh() async {
    setState(() => _students = _loadStudents());
    await _students;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CourseRosterMember>>(
      future: _students,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorState(
            message: 'Unable to load the class roster.',
            onRetry: _refresh,
          );
        }

        final students = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text('People', style: AppTextStyles.h3)),
                  ?widget.courseMenu,
                ],
              ),
              const SizedBox(height: 20),
              Text('INSTRUCTOR', style: _sectionStyle(context)),
              const SizedBox(height: 8),
              _PersonTile(
                name: widget.course.instructorName,
                avatarUrl: widget.course.instructorAvatarUrl,
                role: 'Instructor',
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('STUDENTS', style: _sectionStyle(context)),
                  const Spacer(),
                  Text(
                    '${students.length}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No students have joined yet.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...students.map(
                  (student) => _PersonTile(
                    name: student.displayName,
                    avatarUrl: student.avatarUrl,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _sectionStyle(BuildContext context) {
    return AppTextStyles.caption.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? role;

  const _PersonTile({required this.name, this.avatarUrl, this.role});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: avatarUrl?.isNotEmpty == true
            ? NetworkImage(avatarUrl!)
            : null,
        child: avatarUrl?.isNotEmpty == true ? null : Text(initials),
      ),
      title: Text(name, style: AppTextStyles.bodyLarge),
      subtitle: role == null
          ? null
          : Text(
              role!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
    );
  }
}

class _StudentCourseProgressCard extends StatefulWidget {
  final String courseId;
  final String enrollmentId;

  const _StudentCourseProgressCard({
    required this.courseId,
    required this.enrollmentId,
  });

  @override
  State<_StudentCourseProgressCard> createState() =>
      _StudentCourseProgressCardState();
}

class _StudentCourseProgressCardState
    extends State<_StudentCourseProgressCard> {
  late Future<_CourseProgressSummary> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = _loadProgress();
  }

  @override
  void didUpdateWidget(covariant _StudentCourseProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.enrollmentId != widget.enrollmentId) {
      _progressFuture = _loadProgress();
    }
  }

  Future<_CourseProgressSummary> _loadProgress() async {
    final lessonRepository = context.read<LessonRepository>();
    final lessons = await lessonRepository.getLessons(widget.courseId);
    final lessonProgress = await lessonRepository.getCourseProgress(
      widget.courseId,
      widget.enrollmentId,
    );

    return _CourseProgressSummary(
      completedLessons: lessonProgress
          .where((progress) => progress.isCompleted)
          .length,
      totalLessons: lessons.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CourseProgressSummary>(
      future: _progressFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final completedLessons = summary?.completedLessons ?? 0;
        final totalLessons = summary?.totalLessons ?? 0;
        final progress = totalLessons == 0
            ? 0.0
            : completedLessons / totalLessons;

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
      },
    );
  }
}

class _CourseProgressSummary {
  final int completedLessons;
  final int totalLessons;

  const _CourseProgressSummary({
    required this.completedLessons,
    required this.totalLessons,
  });
}

/// Widget showing quizzes for a course
class _CourseQuizzesSection extends StatefulWidget {
  final String courseId;
  final bool canManage;

  const _CourseQuizzesSection({
    required this.courseId,
    required this.canManage,
  });

  @override
  State<_CourseQuizzesSection> createState() => _CourseQuizzesSectionState();
}

class _CourseQuizzesSectionState extends State<_CourseQuizzesSection> {
  late Future<List<QuizModel>> _quizzesFuture;

  @override
  void initState() {
    super.initState();
    _refreshQuizzes();
  }

  void _refreshQuizzes() {
    _quizzesFuture = context.read<QuizRepository>().getQuizzesByCourse(
      widget.courseId,
      includeUnpublished: widget.canManage,
    );
  }

  void _handleDeleted() {
    if (!mounted) return;
    setState(_refreshQuizzes);
  }

  Future<void> _openQuiz(QuizModel quiz, {bool edit = false}) async {
    final shouldEdit = widget.canManage && (edit || !quiz.isPublished);
    final path = shouldEdit
        ? AppRoutes.editQuizPath(widget.courseId, quiz.id)
        : AppRoutes.quizPath(widget.courseId, quiz.id);
    await context.push(path);
    if (mounted) setState(_refreshQuizzes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuizModel>>(
      future: _quizzesFuture,
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
        onTap: () => _openQuiz(quiz),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          quiz.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!quiz.isPublished) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Draft',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.warning,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                        ],
                      ),
                      if (quiz.timeLimitMinutes > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                        ),
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
            if (widget.canManage) ...[
              IconButton(
                key: ValueKey('edit-quiz-${quiz.id}'),
                tooltip: quiz.isPublished ? 'Edit quiz' : 'Continue editing',
                onPressed: () => _openQuiz(quiz, edit: true),
                color: AppColors.primary,
                icon: const Icon(Icons.edit_outlined),
              ),
              QuizDeleteButton(quiz: quiz, onDeleted: _handleDeleted),
            ] else
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
