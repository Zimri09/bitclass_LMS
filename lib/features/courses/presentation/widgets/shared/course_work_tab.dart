part of '../../screens/course_detail_screen.dart';

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
                  child: Text('Quizzes & Activities', style: AppTextStyles.h3),
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
                        child: Text('Add activity'),
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
              Tab(text: 'Activities'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (widget.canManage) ...[
                        const SizedBox(width: 4),
                        IconButtonTheme(
                          data: IconButtonThemeData(
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(36),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey('edit-quiz-${quiz.id}'),
                                tooltip: quiz.isPublished
                                    ? 'Edit quiz'
                                    : 'Continue editing',
                                onPressed: () => _openQuiz(quiz, edit: true),
                                color: AppColors.primary,
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              QuizDeleteButton(
                                quiz: quiz,
                                onDeleted: _handleDeleted,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formatPostedDateTime(quiz.createdAt),
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
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
          ],
        ),
      ),
    );
  }
}
