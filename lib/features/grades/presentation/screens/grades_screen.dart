import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../quizzes/data/models/quiz_attempt_model.dart';
import '../../../assignments/data/models/submission_model.dart';
import '../../data/models/models.dart';
import '../bloc/grades_bloc.dart';
import '../bloc/grades_event.dart';
import '../bloc/grades_state.dart';

/// Screen showing all grades for a student
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Grades', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Quizzes'),
            Tab(text: 'Assignments'),
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
            return TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(state.summary),
                _buildQuizzesTab(state.summary),
                _buildAssignmentsTab(state.summary),
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
        subtitle: 'Enroll in courses and complete quizzes/assignments',
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
        subtitle: 'Complete quizzes to see your scores',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gradedAttempts.length,
      itemBuilder: (context, index) {
        final attempt = gradedAttempts[index];
        return _QuizAttemptCard(attempt: attempt);
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
        title: 'No assignment grades',
        subtitle: 'Submit assignments to see your grades',
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
          // Stats row
          Row(
            children: [
              _buildStatItem(
                Icons.quiz_outlined,
                '${courseGrade.gradedQuizAttempts.length} Quizzes',
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                Icons.assignment_outlined,
                '${courseGrade.gradedSubmissions.length} Assignments',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
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

  const _QuizAttemptCard({required this.attempt});

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
                  'Quiz Attempt #${attempt.attemptNumber}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
    const maxPoints = 100; // Default max points for assignments
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
      child: Row(
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
                  'Assignment Submission',
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
                '$grade/$maxPoints',
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
