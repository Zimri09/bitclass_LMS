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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
              padding: EdgeInsets.all(18),
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

        if (!kIsWeb) {
          return Column(
            children: quizzes
                .map((quiz) => _buildQuizCard(context, quiz))
                .toList(),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            const maxCardWidth = 370.0;
            const minCardWidth = 280.0;

            final availableWidth = constraints.maxWidth;
            final count = (availableWidth / (maxCardWidth + gap)).floor();
            final columns = count < 1 ? 1 : count;

            final double tileWidth;
            if (columns == 1) {
              tileWidth = availableWidth > maxCardWidth
                  ? maxCardWidth
                  : availableWidth;
            } else {
              final computed =
                  (availableWidth - gap * (columns - 1)) / columns;
              tileWidth = computed.clamp(minCardWidth, maxCardWidth);
            }

            return Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: quizzes
                    .map(
                      (quiz) => SizedBox(
                        width: tileWidth,
                        child: _buildQuizCard(context, quiz),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlowCard(
        glowColor: AppColors.secondary,
        glowIntensity: 0.08,
        onTap: () => _openQuiz(quiz),
        borderRadius: 14,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _WorkTypeLabel(
                  label: 'QUIZ',
                  color: AppColors.secondary,
                  icon: Icons.quiz_outlined,
                ),
                if (!quiz.isPublished) ...[
                  const SizedBox(width: 6),
                  const _WorkStatusLabel(label: 'Draft'),
                ],
                const Spacer(),
                if (widget.canManage)
                  IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(28),
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
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        QuizDeleteButton(quiz: quiz, onDeleted: _handleDeleted),
                      ],
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quiz.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _WorkMeta(
                  icon: Icons.schedule_outlined,
                  label: formatPostedDateTime(quiz.createdAt),
                ),
                if (quiz.dueDate != null)
                  _WorkMeta(
                    icon: Icons.event_available_outlined,
                    label: formatDueDateTime(quiz.dueDate!),
                  ),
                _WorkMeta(
                  icon: Icons.star_outline,
                  label: '${quiz.totalPoints} pts',
                ),
                if (quiz.timeLimitMinutes > 0)
                  _WorkMeta(
                    icon: Icons.timer_outlined,
                    label: '${quiz.timeLimitMinutes}m',
                  ),
                Text(
                  '${quiz.passingScore}% to pass',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (!widget.canManage) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openQuiz(quiz),
                  icon: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: const Text('Take quiz'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkTypeLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _WorkTypeLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkStatusLabel extends StatelessWidget {
  final String label;

  const _WorkStatusLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WorkMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WorkMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
