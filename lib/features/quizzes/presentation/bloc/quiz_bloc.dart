import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/quiz_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Events
// ═══════════════════════════════════════════════════════════════════════════

abstract class QuizEvent extends Equatable {
  const QuizEvent();

  @override
  List<Object?> get props => [];
}

/// Load all quizzes for a course
class LoadQuizzes extends QuizEvent {
  final String courseId;
  final String userId;

  const LoadQuizzes({required this.courseId, required this.userId});

  @override
  List<Object?> get props => [courseId, userId];
}

/// Load a specific quiz with questions
class LoadQuiz extends QuizEvent {
  final String quizId;
  final String userId;

  const LoadQuiz({required this.quizId, required this.userId});

  @override
  List<Object?> get props => [quizId, userId];
}

/// Start a quiz attempt
class StartQuizAttempt extends QuizEvent {
  final String quizId;
  final String userId;
  final String? enrollmentId;

  const StartQuizAttempt({
    required this.quizId,
    required this.userId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props => [quizId, userId, enrollmentId];
}

/// Answer a question
class AnswerQuestion extends QuizEvent {
  final String attemptId;
  final String questionId;
  final List<String>? selectedAnswers;
  final String? textAnswer;
  final String? codeAnswer;

  const AnswerQuestion({
    required this.attemptId,
    required this.questionId,
    this.selectedAnswers,
    this.textAnswer,
    this.codeAnswer,
  });

  @override
  List<Object?> get props => [
    attemptId,
    questionId,
    selectedAnswers,
    textAnswer,
    codeAnswer,
  ];
}

/// Navigate to next question
class NextQuestion extends QuizEvent {
  const NextQuestion();
}

/// Navigate to previous question
class PreviousQuestion extends QuizEvent {
  const PreviousQuestion();
}

/// Jump to a specific question
class GoToQuestion extends QuizEvent {
  final int questionIndex;

  const GoToQuestion(this.questionIndex);

  @override
  List<Object?> get props => [questionIndex];
}

/// Submit the quiz for grading
class SubmitQuiz extends QuizEvent {
  final String attemptId;

  const SubmitQuiz(this.attemptId);

  @override
  List<Object?> get props => [attemptId];
}

/// Load quiz results
class LoadQuizResults extends QuizEvent {
  final String attemptId;

  const LoadQuizResults(this.attemptId);

  @override
  List<Object?> get props => [attemptId];
}

/// Timer tick event
class TimerTick extends QuizEvent {
  final int remainingSeconds;

  const TimerTick(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

// ═══════════════════════════════════════════════════════════════════════════
// States
// ═══════════════════════════════════════════════════════════════════════════

abstract class QuizState extends Equatable {
  const QuizState();

  @override
  List<Object?> get props => [];
}

class QuizInitial extends QuizState {}

class QuizLoading extends QuizState {}

/// List of quizzes loaded
class QuizzesLoaded extends QuizState {
  final String courseId;
  final List<QuizModel> quizzes;
  final Map<String, QuizAttemptModel?> bestAttempts;

  const QuizzesLoaded({
    required this.courseId,
    required this.quizzes,
    this.bestAttempts = const {},
  });

  @override
  List<Object?> get props => [courseId, quizzes, bestAttempts];
}

/// Quiz detail loaded (before starting)
class QuizDetailLoaded extends QuizState {
  final QuizModel quiz;
  final int questionCount;
  final List<QuizAttemptModel> previousAttempts;
  final bool canAttempt;
  final int attemptsRemaining;

  const QuizDetailLoaded({
    required this.quiz,
    required this.questionCount,
    this.previousAttempts = const [],
    this.canAttempt = true,
    required this.attemptsRemaining,
  });

  @override
  List<Object?> get props => [
    quiz,
    questionCount,
    previousAttempts,
    canAttempt,
    attemptsRemaining,
  ];
}

/// Quiz is in progress
class QuizInProgress extends QuizState {
  final QuizModel quiz;
  final List<QuestionModel> questions;
  final QuizAttemptModel attempt;
  final int currentQuestionIndex;
  final int remainingSeconds; // -1 = no time limit
  final bool isSubmitting;

  const QuizInProgress({
    required this.quiz,
    required this.questions,
    required this.attempt,
    this.currentQuestionIndex = 0,
    this.remainingSeconds = -1,
    this.isSubmitting = false,
  });

  QuestionModel get currentQuestion => questions[currentQuestionIndex];

  bool get isFirstQuestion => currentQuestionIndex == 0;

  bool get isLastQuestion => currentQuestionIndex == questions.length - 1;

  UserAnswerModel? get currentAnswer => attempt.answers[currentQuestion.id];

  int get answeredCount =>
      questions.where((q) => attempt.answers.containsKey(q.id)).length;

  @override
  List<Object?> get props => [
    quiz,
    questions,
    attempt,
    currentQuestionIndex,
    remainingSeconds,
    isSubmitting,
  ];

  QuizInProgress copyWith({
    QuizModel? quiz,
    List<QuestionModel>? questions,
    QuizAttemptModel? attempt,
    int? currentQuestionIndex,
    int? remainingSeconds,
    bool? isSubmitting,
  }) {
    return QuizInProgress(
      quiz: quiz ?? this.quiz,
      questions: questions ?? this.questions,
      attempt: attempt ?? this.attempt,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Quiz submitted and graded
class QuizCompleted extends QuizState {
  final QuizModel quiz;
  final QuizAttemptModel attempt;
  final List<QuestionModel> questions;

  const QuizCompleted({
    required this.quiz,
    required this.attempt,
    required this.questions,
  });

  @override
  List<Object?> get props => [quiz, attempt, questions];
}

/// Error state
class QuizError extends QuizState {
  final String message;

  const QuizError(this.message);

  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════════════════
// Bloc
// ═══════════════════════════════════════════════════════════════════════════

class QuizBloc extends Bloc<QuizEvent, QuizState> {
  final QuizRepository quizRepository;
  Timer? _timer;

  QuizBloc({required this.quizRepository}) : super(QuizInitial()) {
    on<LoadQuizzes>(_onLoadQuizzes);
    on<LoadQuiz>(_onLoadQuiz);
    on<StartQuizAttempt>(_onStartAttempt);
    on<AnswerQuestion>(_onAnswerQuestion);
    on<NextQuestion>(_onNextQuestion);
    on<PreviousQuestion>(_onPreviousQuestion);
    on<GoToQuestion>(_onGoToQuestion);
    on<SubmitQuiz>(_onSubmitQuiz);
    on<LoadQuizResults>(_onLoadResults);
    on<TimerTick>(_onTimerTick);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> _onLoadQuizzes(
    LoadQuizzes event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());

    try {
      final quizzes = await quizRepository.getQuizzesByCourse(event.courseId);

      // Get best attempts for each quiz
      final bestAttempts = <String, QuizAttemptModel?>{};
      for (final quiz in quizzes) {
        bestAttempts[quiz.id] = await quizRepository.getBestAttempt(
          quizId: quiz.id,
          userId: event.userId,
        );
      }

      emit(
        QuizzesLoaded(
          courseId: event.courseId,
          quizzes: quizzes,
          bestAttempts: bestAttempts,
        ),
      );
    } catch (e) {
      emit(QuizError('Failed to load quizzes: $e'));
    }
  }

  Future<void> _onLoadQuiz(LoadQuiz event, Emitter<QuizState> emit) async {
    emit(QuizLoading());

    try {
      final quiz = await quizRepository.getQuiz(event.quizId);
      if (quiz == null) {
        emit(const QuizError('Quiz not found'));
        return;
      }

      final questions = await quizRepository.getQuestions(event.quizId);
      final attempts = await quizRepository.getAttempts(
        quizId: event.quizId,
        userId: event.userId,
      );

      final gradedAttempts = attempts
          .where((a) => a.status == AttemptStatus.graded)
          .toList();

      int attemptsRemaining;
      bool canAttempt;

      if (quiz.maxAttempts == 0) {
        attemptsRemaining = -1; // Unlimited
        canAttempt = true;
      } else {
        attemptsRemaining = quiz.maxAttempts - gradedAttempts.length;
        canAttempt = attemptsRemaining > 0;
      }

      emit(
        QuizDetailLoaded(
          quiz: quiz,
          questionCount: questions.length,
          previousAttempts: gradedAttempts,
          canAttempt: canAttempt,
          attemptsRemaining: attemptsRemaining,
        ),
      );
    } catch (e) {
      emit(QuizError('Failed to load quiz: $e'));
    }
  }

  Future<void> _onStartAttempt(
    StartQuizAttempt event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());

    try {
      final quiz = await quizRepository.getQuiz(event.quizId);
      if (quiz == null) {
        emit(const QuizError('Quiz not found'));
        return;
      }

      final questions = await quizRepository.getQuestions(event.quizId);
      if (questions.isEmpty) {
        emit(const QuizError('Quiz has no questions'));
        return;
      }

      final attempt = await quizRepository.startAttempt(
        quizId: event.quizId,
        userId: event.userId,
        enrollmentId: event.enrollmentId,
      );

      // Shuffle questions if enabled
      final orderedQuestions = quiz.shuffleQuestions
          ? (List<QuestionModel>.from(questions)..shuffle())
          : questions;

      // Start timer if time limit exists
      int remainingSeconds = -1;
      if (quiz.timeLimitMinutes > 0) {
        remainingSeconds = quiz.timeLimitMinutes * 60;
        _startTimer(remainingSeconds);
      }

      emit(
        QuizInProgress(
          quiz: quiz,
          questions: orderedQuestions,
          attempt: attempt,
          currentQuestionIndex: 0,
          remainingSeconds: remainingSeconds,
        ),
      );
    } catch (e) {
      emit(QuizError('Failed to start quiz: $e'));
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = seconds - timer.tick;
      if (remaining <= 0) {
        timer.cancel();
        // Auto-submit when time runs out
        final currentState = state;
        if (currentState is QuizInProgress) {
          add(SubmitQuiz(currentState.attempt.id));
        }
      } else {
        add(TimerTick(remaining));
      }
    });
  }

  void _onTimerTick(TimerTick event, Emitter<QuizState> emit) {
    final currentState = state;
    if (currentState is QuizInProgress) {
      emit(currentState.copyWith(remainingSeconds: event.remainingSeconds));
    }
  }

  Future<void> _onAnswerQuestion(
    AnswerQuestion event,
    Emitter<QuizState> emit,
  ) async {
    final currentState = state;
    if (currentState is! QuizInProgress) return;

    try {
      final updatedAttempt = await quizRepository.saveAnswer(
        attemptId: event.attemptId,
        questionId: event.questionId,
        selectedAnswers: event.selectedAnswers,
        textAnswer: event.textAnswer,
        codeAnswer: event.codeAnswer,
      );

      emit(currentState.copyWith(attempt: updatedAttempt));
    } catch (e) {
      // Don't emit error, just log - answer saving shouldn't block UI
    }
  }

  void _onNextQuestion(NextQuestion event, Emitter<QuizState> emit) {
    final currentState = state;
    if (currentState is! QuizInProgress) return;

    if (!currentState.isLastQuestion) {
      emit(
        currentState.copyWith(
          currentQuestionIndex: currentState.currentQuestionIndex + 1,
        ),
      );
    }
  }

  void _onPreviousQuestion(PreviousQuestion event, Emitter<QuizState> emit) {
    final currentState = state;
    if (currentState is! QuizInProgress) return;

    if (!currentState.isFirstQuestion) {
      emit(
        currentState.copyWith(
          currentQuestionIndex: currentState.currentQuestionIndex - 1,
        ),
      );
    }
  }

  void _onGoToQuestion(GoToQuestion event, Emitter<QuizState> emit) {
    final currentState = state;
    if (currentState is! QuizInProgress) return;

    if (event.questionIndex >= 0 &&
        event.questionIndex < currentState.questions.length) {
      emit(currentState.copyWith(currentQuestionIndex: event.questionIndex));
    }
  }

  Future<void> _onSubmitQuiz(SubmitQuiz event, Emitter<QuizState> emit) async {
    final currentState = state;
    if (currentState is! QuizInProgress) return;

    _timer?.cancel();

    emit(currentState.copyWith(isSubmitting: true));

    try {
      final gradedAttempt = await quizRepository.submitAttempt(event.attemptId);

      emit(
        QuizCompleted(
          quiz: currentState.quiz,
          attempt: gradedAttempt,
          questions: currentState.questions,
        ),
      );
    } catch (e) {
      emit(QuizError('Failed to submit quiz: $e'));
    }
  }

  Future<void> _onLoadResults(
    LoadQuizResults event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizLoading());

    try {
      final attempt = await quizRepository.getAttempt(event.attemptId);
      if (attempt == null) {
        emit(const QuizError('Attempt not found'));
        return;
      }

      final quiz = await quizRepository.getQuiz(attempt.quizId);
      if (quiz == null) {
        emit(const QuizError('Quiz not found'));
        return;
      }

      final questions = await quizRepository.getQuestions(attempt.quizId);

      emit(QuizCompleted(quiz: quiz, attempt: attempt, questions: questions));
    } catch (e) {
      emit(QuizError('Failed to load results: $e'));
    }
  }
}
