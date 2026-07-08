import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/quiz_repository.dart';
import '../bloc/quiz_bloc.dart';

/// Screen for taking a quiz
class QuizScreen extends StatefulWidget {
  final String courseId;
  final String quizId;

  const QuizScreen({super.key, required this.courseId, required this.quizId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late QuizBloc _quizBloc;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final Set<String> _selectedAnswers = {};

  bool get _isInstructor {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.user.role == 'instructor';
  }

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return 'demo_user';
  }

  @override
  void initState() {
    super.initState();
    _quizBloc = QuizBloc(quizRepository: context.read<QuizRepository>());
    _loadQuiz();
  }

  void _loadQuiz() {
    _quizBloc.add(LoadQuiz(quizId: widget.quizId, userId: _currentUserId));
  }

  @override
  void dispose() {
    _textController.dispose();
    _codeController.dispose();
    _quizBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _quizBloc,
      child: BlocConsumer<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state is QuizError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is QuizInProgress) {
            // Reset answer inputs when question changes
            _updateInputsForQuestion(state);
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: _buildAppBar(context, state),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  void _updateInputsForQuestion(QuizInProgress state) {
    final answer = state.currentAnswer;
    _selectedAnswers.clear();
    if (answer != null) {
      _selectedAnswers.addAll(answer.selectedAnswers);
      _textController.text = answer.textAnswer ?? '';
      _codeController.text = answer.codeAnswer ?? '';
    } else {
      _textController.clear();
      _codeController.clear();
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, QuizState state) {
    String title = 'Quiz';
    Widget? timerWidget;

    if (state is QuizDetailLoaded) {
      title = state.quiz.title;
    } else if (state is QuizInProgress) {
      title = state.quiz.title;
      if (state.remainingSeconds > 0) {
        timerWidget = _buildTimer(state.remainingSeconds);
      }
    } else if (state is QuizCompleted) {
      title = 'Quiz Results';
    }

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.close),
        onPressed: () => _showExitConfirmation(context, state),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: [?timerWidget],
    );
  }

  Widget _buildTimer(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final isLow = seconds < 60;

    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLow
            ? AppColors.error.withValues(alpha: 0.2)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: isLow ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isLow ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, QuizState state) {
    if (state is QuizLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is QuizError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(state.message),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadQuiz, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (state is QuizDetailLoaded) {
      return _buildQuizDetails(context, state);
    }

    if (state is QuizInProgress) {
      return _buildQuizInProgress(context, state);
    }

    if (state is QuizCompleted) {
      return _buildQuizResults(context, state);
    }

    return const Center(child: Text('Loading...'));
  }

  Widget _buildQuizDetails(BuildContext context, QuizDetailLoaded state) {
    final quiz = state.quiz;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final padding = isMobile ? 16.0 : 24.0;
    final isInstructor = _isInstructor;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz header
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (quiz.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              quiz.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Quiz info
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildInfoChip(
                      Icons.help_outline,
                      '${state.questionCount} Questions',
                    ),
                    _buildInfoChip(
                      Icons.star_outline,
                      '${quiz.totalPoints} Points',
                    ),
                    if (quiz.timeLimitMinutes > 0)
                      _buildInfoChip(
                        Icons.timer_outlined,
                        '${quiz.timeLimitMinutes} Minutes',
                      ),
                    _buildInfoChip(
                      Icons.check_circle_outline,
                      '${quiz.passingScore}% to Pass',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Previous attempts
          if (!isInstructor && state.previousAttempts.isNotEmpty) ...[
            Text(
              'Previous Attempts',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...state.previousAttempts.map((a) => _buildAttemptCard(a)),
            const SizedBox(height: 24),
          ],

          // Attempts remaining
          if (!isInstructor && state.attemptsRemaining > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.repeat, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    state.attemptsRemaining == -1
                        ? 'Unlimited attempts'
                        : '${state.attemptsRemaining} attempt(s) remaining',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (!isInstructor) ...[
            // Start button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.canAttempt ? _startQuiz : null,
                icon: Icon(Icons.play_arrow),
                label: Text(
                  state.previousAttempts.isEmpty ? 'Start Quiz' : 'Retake Quiz',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            if (!state.canAttempt) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'No attempts remaining',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: AppColors.info, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Instructor preview mode',
                    style: TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(QuizAttemptModel attempt) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: attempt.passed
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.error.withValues(alpha: 0.2),
          child: Icon(
            attempt.passed ? Icons.check : Icons.close,
            color: attempt.passed ? AppColors.success : AppColors.error,
          ),
        ),
        title: Text(
          'Attempt ${attempt.attemptNumber}',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          '${attempt.score}/${attempt.totalPoints} points (${attempt.percentage.round()}%)',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Text(
          attempt.passed ? 'Passed' : 'Failed',
          style: TextStyle(
            color: attempt.passed ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _startQuiz() {
    if (_isInstructor) {
      return;
    }

    _quizBloc.add(
      StartQuizAttempt(quizId: widget.quizId, userId: _currentUserId),
    );
  }

  Widget _buildQuizInProgress(BuildContext context, QuizInProgress state) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (state.currentQuestionIndex + 1) / state.questions.length,
          backgroundColor: AppColors.surfaceLight,
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            ),
            child: _buildQuestion(context, state),
          ),
        ),
        // Navigation
        _buildQuizNavigation(context, state),
      ],
    );
  }

  Widget _buildQuestion(BuildContext context, QuizInProgress state) {
    final question = state.currentQuestion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question number
        Text(
          'Question ${state.currentQuestionIndex + 1} of ${state.questions.length}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // Points
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${question.points} ${question.points == 1 ? 'point' : 'points'}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Question text
        Text(
          question.questionText,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        // Code snippet if present
        if (question.questionCode != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: SelectableText(
              question.questionCode!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Answer area
        _buildAnswerArea(question, state),
        // Hint
        if (question.hint != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hint: ${question.hint}',
                    style: TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnswerArea(QuestionModel question, QuizInProgress state) {
    switch (question.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        return _buildMultipleChoice(question, state, singleSelect: true);
      case QuestionType.multipleSelect:
        return _buildMultipleChoice(question, state, singleSelect: false);
      case QuestionType.shortAnswer:
        return _buildShortAnswer(question, state);
      case QuestionType.coding:
        return _buildCodingAnswer(question, state);
    }
  }

  Widget _buildMultipleChoice(
    QuestionModel question,
    QuizInProgress state, {
    required bool singleSelect,
  }) {
    final options = question.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!singleSelect)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Select all that apply',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ...options.map((option) {
          final isSelected = _selectedAnswers.contains(option.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (singleSelect) {
                    _selectedAnswers.clear();
                    _selectedAnswers.add(option.id);
                  } else {
                    if (isSelected) {
                      _selectedAnswers.remove(option.id);
                    } else {
                      _selectedAnswers.add(option.id);
                    }
                  }
                });
                _saveAnswer(question, state);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: singleSelect
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                        borderRadius: singleSelect
                            ? null
                            : BorderRadius.circular(4),
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.text,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (option.code != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                option.code!,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildShortAnswer(QuestionModel question, QuizInProgress state) {
    return TextField(
      controller: _textController,
      decoration: InputDecoration(
        hintText: 'Type your answer here...',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.surfaceLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      style: TextStyle(color: AppColors.textPrimary),
      onChanged: (_) => _saveAnswer(question, state),
    );
  }

  Widget _buildCodingAnswer(QuestionModel question, QuizInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: TextField(
            controller: _codeController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              hintText: 'Write your code here...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(color: AppColors.textSecondary),
            ),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              color: AppColors.secondary,
              height: 1.5,
            ),
            cursorColor: AppColors.secondary,
            onChanged: (_) => _saveAnswer(question, state),
          ),
        ),
        // Test cases preview
        if (question.testCases != null) ...[
          const SizedBox(height: 16),
          Text(
            'Test Cases:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...question.testCases!
              .where((tc) => !tc.isHidden)
              .map(
                (tc) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Input: ${tc.input}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Expected: ${tc.expectedOutput}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }

  void _saveAnswer(QuestionModel question, QuizInProgress state) {
    _quizBloc.add(
      AnswerQuestion(
        attemptId: state.attempt.id,
        questionId: question.id,
        selectedAnswers: _selectedAnswers.isNotEmpty
            ? _selectedAnswers.toList()
            : null,
        textAnswer: _textController.text.isNotEmpty
            ? _textController.text
            : null,
        codeAnswer: _codeController.text.isNotEmpty
            ? _codeController.text
            : null,
      ),
    );
  }

  Widget _buildQuizNavigation(BuildContext context, QuizInProgress state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: Column(
        children: [
          // Question indicators
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.questions.length,
              itemBuilder: (context, index) {
                final question = state.questions[index];
                final isAnswered = state.attempt.answers.containsKey(
                  question.id,
                );
                final isCurrent = index == state.currentQuestionIndex;

                return GestureDetector(
                  onTap: () => _quizBloc.add(GoToQuestion(index)),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary
                          : isAnswered
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent
                          ? null
                          : Border.all(
                              color: isAnswered
                                  ? AppColors.success
                                  : AppColors.textSecondary.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? Colors.white
                              : isAnswered
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Navigation buttons
          Row(
            children: [
              if (!state.isFirstQuestion)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quizBloc.add(const PreviousQuestion()),
                    icon: Icon(Icons.arrow_back, size: 18),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              if (state.isLastQuestion)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () => _showSubmitConfirmation(context, state),
                    icon: state.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.check, size: 18),
                    label: const Text('Submit'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.success,
                    ),
                  ),
                )
              else
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _quizBloc.add(const NextQuestion()),
                    icon: const Text('Next'),
                    label: Icon(Icons.arrow_forward, size: 18),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuizResults(BuildContext context, QuizCompleted state) {
    final attempt = state.attempt;
    final passed = attempt.passed;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Result header
          Container(
            padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
            decoration: BoxDecoration(
              color: passed
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: passed
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.celebration : Icons.sentiment_dissatisfied,
                  size: 64,
                  color: passed ? AppColors.success : AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? 'Congratulations!' : 'Keep Practicing!',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  passed
                      ? 'You passed the quiz!'
                      : 'You didn\'t pass this time',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // Score circle
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: attempt.percentage / 100,
                          strokeWidth: 8,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(
                            passed ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${attempt.percentage.round()}%',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: passed
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          Text(
                            '${attempt.score}/${attempt.totalPoints}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
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
          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Time Spent',
                  _formatTime(attempt.timeSpentSeconds),
                  Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Correct',
                  '${attempt.answers.values.where((a) => a.isCorrect).length}/${state.questions.length}',
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Question review
          if (state.quiz.showCorrectAnswers) ...[
            Text(
              'Question Review',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...state.questions.map((q) => _buildQuestionReview(q, attempt)),
          ],

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back to Course'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _loadQuiz,
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionReview(
    QuestionModel question,
    QuizAttemptModel attempt,
  ) {
    final answer = attempt.answers[question.id];
    final isCorrect = answer?.isCorrect ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.questionText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${answer?.pointsEarned ?? 0}/${question.points}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          if (answer?.feedback != null) ...[
            const SizedBox(height: 8),
            Text(
              answer!.feedback!,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }

  void _showExitConfirmation(BuildContext context, QuizState state) {
    if (state is QuizInProgress) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Exit Quiz?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Your progress will be lost if you exit now.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  void _showSubmitConfirmation(BuildContext context, QuizInProgress state) {
    final unanswered = state.questions.length - state.answeredCount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Submit Quiz?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unanswered > 0)
              Text(
                'You have $unanswered unanswered question(s).',
                style: TextStyle(color: AppColors.warning),
              ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to submit?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _quizBloc.add(SubmitQuiz(state.attempt.id));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
