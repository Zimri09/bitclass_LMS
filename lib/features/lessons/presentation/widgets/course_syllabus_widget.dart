import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/lesson_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/lesson_repository.dart';
import '../bloc/lesson_bloc.dart';

/// Widget displaying the course syllabus with modules and lessons
class CourseSyllabusWidget extends StatefulWidget {
  final String courseId;
  final bool showHeader;

  const CourseSyllabusWidget({
    super.key,
    required this.courseId,
    this.showHeader = true,
  });

  @override
  State<CourseSyllabusWidget> createState() => _CourseSyllabusWidgetState();
}

class _CourseSyllabusWidgetState extends State<CourseSyllabusWidget> {
  late LessonBloc _lessonBloc;
  final Set<String> _expandedModules = {};

  @override
  void initState() {
    super.initState();
    _lessonBloc = LessonBloc(
      lessonRepository: context.read<LessonRepository>(),
    );
    _loadModulesAndLessons();
  }

  void _loadModulesAndLessons() {
    _lessonBloc.add(LoadModulesAndLessons(widget.courseId));
  }

  @override
  void dispose() {
    _lessonBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _lessonBloc,
      child: BlocBuilder<LessonBloc, LessonState>(
        builder: (context, state) {
          if (state is LessonLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (state is LessonError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load syllabus',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loadModulesAndLessons,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ModulesAndLessonsLoaded) {
            return _buildSyllabus(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSyllabus(BuildContext context, ModulesAndLessonsLoaded state) {
    final modules = state.modules;
    final lessonsByModule = state.lessonsByModule;
    final progressByLesson = state.progressByLesson;
    final authState = context.read<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.role == 'instructor';

    // Collect all lessons
    final allLessons = lessonsByModule.values.expand((l) => l).toList();

    if (modules.isEmpty && allLessons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No content yet',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Course content is being prepared',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate total progress
    final totalLessons = state.totalLessons;
    final completedLessons = state.completedLessons;
    final progressPercent = state.completionPercentage.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          // Syllabus header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Course Content',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!isInstructor)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$completedLessons/$totalLessons lessons • $progressPercent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Module list
        if (modules.isNotEmpty) ...[
          ...modules.map(
            (module) => _buildModuleTile(
              context,
              module,
              lessonsByModule[module.id] ?? [],
              progressByLesson,
            ),
          ),
        ],

        // Standalone lessons (not in any module)
        ...(lessonsByModule[''] ?? []).map(
          (lesson) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: LessonTile(
                title: lesson.title,
                description: lesson.description,
                durationMinutes: lesson.durationMinutes,
                typeIcon: _getLessonTypeIcon(lesson.type),
                isCompleted: progressByLesson[lesson.id]?.isCompleted == true,
                onTap: () => _navigateToLesson(lesson.id),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleTile(
    BuildContext context,
    ModuleModel module,
    List<LessonModel> moduleLessons,
    Map<String, LessonProgressModel> progressByLesson,
  ) {
    final isExpanded = _expandedModules.contains(module.id);
    final completedCount = moduleLessons.where((lesson) {
      return progressByLesson[lesson.id]?.isCompleted == true;
    }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ModuleTile(
        title: module.title,
        description: module.description,
        lessonCount: moduleLessons.length,
        completedCount: completedCount,
        isExpanded: isExpanded,
        onExpand: () {
          setState(() {
            if (isExpanded) {
              _expandedModules.remove(module.id);
            } else {
              _expandedModules.add(module.id);
            }
          });
        },
        lessons: moduleLessons
            .map(
              (lesson) => LessonTile(
                title: lesson.title,
                description: lesson.description,
                durationMinutes: lesson.durationMinutes,
                typeIcon: _getLessonTypeIcon(lesson.type),
                isCompleted: progressByLesson[lesson.id]?.isCompleted == true,
                onTap: () => _navigateToLesson(lesson.id),
              ),
            )
            .toList(),
      ),
    );
  }

  void _navigateToLesson(String lessonId) {
    context.go('/courses/${widget.courseId}/lessons/$lessonId');
  }

  IconData _getLessonTypeIcon(LessonType type) {
    switch (type) {
      case LessonType.video:
        return Icons.play_circle_outline;
      case LessonType.code:
        return Icons.code;
      case LessonType.quiz:
        return Icons.quiz_outlined;
      case LessonType.text:
        return Icons.article_outlined;
    }
  }
}
