import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../quizzes/data/models/quiz_attempt_model.dart';
import '../../../assignments/data/models/submission_model.dart';
import '../../data/models/models.dart';
import '../bloc/grades_bloc.dart';
import '../bloc/grades_event.dart';
import '../bloc/grades_state.dart';

String _gradeValue(num value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// Screen showing all grades for a student
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGrades();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadGrades() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    context.read<GradesBloc>().add(LoadGrades(userId: authState.user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: Text('My Grades', style: AppTextStyles.h3),
        actions: [
          BlocBuilder<GradesBloc, GradesState>(
            builder: (context, state) => IconButton(
              tooltip: 'Refresh grades',
              onPressed: state is GradesLoading ? null : _loadGrades,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Quizzes'),
            Tab(text: 'Activities'),
          ],
          indicatorColor: AppColors.primary,
        ),
      ),
      body: BlocBuilder<GradesBloc, GradesState>(
        builder: (context, state) {
          if (state is GradesLoading) {
            return const BitClassLoader();
          }
          if (state is GradesError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Error loading grades',
              subtitle: state.message,
            );
          }
          if (state is GradesLoaded) {
            final courses = state.summary.courseGrades;
            if (courses.isEmpty) {
              return const EmptyState(
                icon: Icons.school_outlined,
                title: 'No enrolled courses',
                subtitle: 'Enroll in a course to see your grades here',
              );
            }
            final selected = courses.firstWhere(
              (course) => course.courseId == _selectedCourseId,
              orElse: () => courses.first,
            );
            _selectedCourseId = selected.courseId;
            // Reuse the existing sorting and grade-status filters within
            // a summary containing only the selected course.
            final summary = state.summary.copyWith(courseGrades: [selected]);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selected.courseId,
                        isExpanded: true,
                        items: [
                          for (final course in courses)
                            DropdownMenuItem(
                              value: course.courseId,
                              child: Text(
                                course.course.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCourseId = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(summary),
                      _buildQuizzesTab(summary),
                      _buildAssignmentsTab(summary),
                    ],
                  ),
                ),
              ],
            );
          }
          return const BitClassLoader();
        },
      ),
    );
  }

  Widget _buildOverviewTab(GradesSummaryModel summary) {
    if (summary.courseGrades.isEmpty) {
      return const EmptyState(
        icon: Icons.school_outlined,
        title: 'No grades yet',
        subtitle: 'Enroll in courses and complete quizzes/activities',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summary.courseGrades.length,
      itemBuilder: (context, index) {
        final courseGrade = summary.courseGrades[index];
        return _CourseGradeCard(courseGrade: courseGrade);
      },
    );
  }

  Widget _buildQuizzesTab(GradesSummaryModel summary) {
    final gradedAttempts = summary.allQuizAttempts
        .where((a) => a.status == AttemptStatus.graded)
        .toList();

    if (gradedAttempts.isEmpty) {
      return const EmptyState(
        icon: Icons.quiz_outlined,
        title: 'No quiz grades',
        subtitle: 'No graded quizzes in this course yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gradedAttempts.length,
      itemBuilder: (context, index) {
        final attempt = gradedAttempts[index];
        return _QuizAttemptCard(
          attempt: attempt,
          title: summary.courseGrades.first.quizTitles[attempt.quizId],
        );
      },
    );
  }

  Widget _buildAssignmentsTab(GradesSummaryModel summary) {
    final gradedSubmissions = summary.allAssignmentSubmissions
        .where((s) => s.status == SubmissionStatus.graded)
        .toList();

    if (gradedSubmissions.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No activity grades',
        subtitle: 'No graded activities in this course yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gradedSubmissions.length,
      itemBuilder: (context, index) {
        final submission = gradedSubmissions[index];
        return _AssignmentSubmissionCard(submission: submission);
      },
    );
  }
}

class _CourseGradeCard extends StatelessWidget {
  final CourseGradeModel courseGrade;

  const _CourseGradeCard({required this.courseGrade});

  @override
  Widget build(BuildContext context) {
    final grade = courseGrade.overallGrade;
    final gradeColor = _getGradeColor(grade);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseGrade.course.title,
                      style: AppTextStyles.h4,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${courseGrade.completedItems} graded items',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradeColor.withValues(alpha: 0.1),
                  border: Border.all(color: gradeColor, width: 3),
                ),
                child: Center(
                  child: Text(
                    courseGrade.completedItems > 0
                        ? '${grade.toStringAsFixed(0)}%'
                        : '--',
                    style: AppTextStyles.h4.copyWith(color: gradeColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: grade / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(gradeColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total points: ${_gradeValue(courseGrade.earnedPoints)} / ${_gradeValue(courseGrade.totalPoints)}',
            style: AppTextStyles.bodyMedium,
          ),
          Text('Graded items only', style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildStatItem(
                Icons.quiz_outlined,
                '${courseGrade.gradedQuizAttempts.length} Quizzes',
              ),
              _buildStatItem(
                Icons.assignment_outlined,
                '${courseGrade.gradedSubmissions.length} Activities',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return AppColors.success;
    if (grade >= 70) return AppColors.warning;
    if (grade >= 50) return Colors.orange;
    return AppColors.error;
  }
}

class _QuizAttemptCard extends StatelessWidget {
  final QuizAttemptModel attempt;
  final String? title;

  const _QuizAttemptCard({required this.attempt, this.title});

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor(attempt.percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.quiz, color: gradeColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? 'Quiz Attempt #${attempt.attemptNumber}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title != null)
                  Text(
                    'Attempt #${attempt.attemptNumber}',
                    style: AppTextStyles.caption,
                  ),
                Text(
                  'Completed ${_formatDate(attempt.submittedAt ?? attempt.startedAt)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${attempt.score}/${attempt.totalPoints}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: gradeColor,
                ),
              ),
              Text(
                '${attempt.percentage.toStringAsFixed(0)}%',
                style: AppTextStyles.bodySmall.copyWith(color: gradeColor),
              ),
            ],
          ),
          if (attempt.passed) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
          ],
        ],
      ),
    );
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return AppColors.success;
    if (grade >= 70) return AppColors.warning;
    if (grade >= 50) return Colors.orange;
    return AppColors.error;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _AssignmentSubmissionCard extends StatelessWidget {
  final SubmissionModel submission;

  const _AssignmentSubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final grade = submission.score ?? 0;
    final maxPoints = submission.resolvedMaxPoints;
    final percentage = maxPoints > 0 ? (grade / maxPoints) * 100 : 0.0;
    final gradeColor = _getGradeColor(percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment_turned_in, color: gradeColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.assignmentDisplayTitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Graded ${_formatDate(submission.gradedAt ?? submission.submittedAt ?? submission.createdAt)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (submission.feedback != null &&
                        submission.feedback!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          submission.feedback!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_gradeValue(grade)}/$maxPoints',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: gradeColor,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: AppTextStyles.bodySmall.copyWith(color: gradeColor),
                  ),
                ],
              ),
            ],
          ),
          if (submission.criterionScores.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('Criteria breakdown', style: AppTextStyles.label),
            const SizedBox(height: 6),
            ...submission.criterionScores.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.criterionName)),
                    Text(
                      '${_gradeValue(item.score)}/${_gradeValue(item.maxPoints)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return AppColors.success;
    if (grade >= 70) return AppColors.warning;
    if (grade >= 50) return Colors.orange;
    return AppColors.error;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
