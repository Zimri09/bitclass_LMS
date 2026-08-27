import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/classroom_course_card.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';
import '../bloc/course_bloc.dart';

/// Student course list showing only classes the student has joined.
class CourseCatalogScreen extends StatefulWidget {
  const CourseCatalogScreen({super.key});

  @override
  State<CourseCatalogScreen> createState() => _CourseCatalogScreenState();
}

class _CourseCatalogScreenState extends State<CourseCatalogScreen> {
  List<CourseModel>? _lastVisibleCourses;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    context.read<CourseBloc>().add(const LoadCourses());
  }

  Future<void> _refreshCourses() async {
    final courseBloc = context.read<CourseBloc>();
    final completion = courseBloc.stream.firstWhere(
      (state) => state is CoursesLoaded || state is CourseError,
    );
    courseBloc.add(const LoadCourses());
    await completion;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final canJoinClasses =
        authState is AuthAuthenticated && authState.user.role == 'student';

    return Scaffold(
      body: BlocListener<CourseBloc, CourseState>(
        listener: (context, state) async {
          if (state is CourseJoinedByCode) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Joined "${state.course.title}" successfully!',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 3),
              ),
            );
            await context.push(AppRoutes.courseDetailPath(state.course.id));
            if (mounted) {
              _loadCourses();
            }
          } else if (state is CourseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                action: isNetworkFailure(state.message)
                    ? SnackBarAction(label: 'Retry', onPressed: _loadCourses)
                    : null,
              ),
            );
          }
        },
        child: RefreshIndicator(
          onRefresh: _refreshCourses,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App bar
              SliverAppBar(
                floating: true,
                leading: const AppDrawerButton(),
                title: Text('Classes', style: AppTextStyles.h3),
              ),

              // Course grid
              BlocBuilder<CourseBloc, CourseState>(
                builder: (context, state) {
                  final currentCourses = switch (state) {
                    CoursesLoaded(:final courses) => courses,
                    CourseJoining(:final courses) => courses,
                    CourseJoinFailure(:final courses) => courses,
                    _ => null,
                  };
                  if (currentCourses != null) {
                    _lastVisibleCourses = currentCourses;
                  }
                  final visibleCourses = currentCourses ?? _lastVisibleCourses;

                  if (visibleCourses != null) {
                    if (visibleCourses.isEmpty) {
                      return SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.school_outlined,
                          title: 'No classes joined yet',
                          subtitle:
                              'Use your instructor\'s class code to join one',
                        ),
                      );
                    }

                    return SliverClassroomCourseLayout(
                      itemCount: visibleCourses.length,
                      itemBuilder: (context, index) => _CourseCard(
                        course: visibleCourses[index],
                        onTap: () => _openCourse(visibleCourses[index]),
                        onUnenrolled: _refreshCourses,
                      ),
                    );
                  }

                  if (state is CourseLoading) {
                    return const SliverCourseGridSkeleton();
                  }

                  if (state is CourseError) {
                    return SliverFillRemaining(
                      child: ErrorState(
                        message: state.message,
                        onRetry: _loadCourses,
                      ),
                    );
                  }

                  return const SliverCourseGridSkeleton();
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: canJoinClasses
          ? FloatingActionButton.extended(
              onPressed: () => _showJoinByCodeSheet(context),
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
              label: const Text(
                'Join class',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _openCourse(CourseModel course) async {
    await context.push(AppRoutes.courseDetailPath(course.id));
    if (mounted) {
      _loadCourses();
    }
  }

  /// Shows a bottom sheet for joining a course by its code
  void _showJoinByCodeSheet(BuildContext context) {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: context.read<CourseBloc>(),
          child: BlocConsumer<CourseBloc, CourseState>(
            listener: (ctx, state) {
              if (state is CourseJoinedByCode) {
                Navigator.of(sheetCtx).pop();
              }
            },
            builder: (ctx, state) {
              final isLoading = state is CourseJoining;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Icon + title
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary,
                                      AppColors.primary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.vpn_key_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join a Course',
                                    style: AppTextStyles.h3,
                                  ),
                                  Text(
                                    'Enter the 6-character code from your instructor',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Code input
                          TextFormField(
                            controller: codeController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              UpperCaseTextFormatter(),
                            ],
                            style: AppTextStyles.h2.copyWith(
                              letterSpacing: 8,
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'ABC123',
                              hintStyle: AppTextStyles.h2.copyWith(
                                letterSpacing: 8,
                                color: AppColors.textMuted,
                              ),
                              counterText: '',
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a course code';
                              }
                              if (value.trim().length != 6) {
                                return 'Code must be exactly 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Hint
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ask your instructor for the course code',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          if (state is CourseJoinFailure) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.error.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                state.message,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Join button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (formKey.currentState!.validate()) {
                                        final authState = context
                                            .read<AuthBloc>()
                                            .state;
                                        if (authState is AuthAuthenticated) {
                                          context.read<CourseBloc>().add(
                                            JoinCourseByCode(
                                              code: codeController.text.trim(),
                                              userId: authState.user.id,
                                              studentName: authState
                                                  .user
                                                  .displayNameOrEmail,
                                              studentEmail:
                                                  authState.user.email,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                isLoading ? 'Joining...' : 'Join Course',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: AppTextStyles.buttonMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;
  final Future<void> Function() onUnenrolled;

  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.onUnenrolled,
  });

  @override
  Widget build(BuildContext context) {
    return ClassroomCourseCard(
      course: course,
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        tooltip: 'Class options',
        onPressed: () => _showClassOptions(context),
      ),
      footer: [
        Icon(Icons.people_outline, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('${course.enrollmentCount}', style: AppTextStyles.caption),
        const SizedBox(width: 14),
        Icon(Icons.menu_book_outlined, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('${course.lessonCount}', style: AppTextStyles.caption),
      ],
    );
  }

  void _showClassOptions(BuildContext context) {
    showModalBottomSheet<void>(
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

/// TextInputFormatter that converts all input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
