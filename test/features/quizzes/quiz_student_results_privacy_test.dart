import 'dart:async';

import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/quizzes/data/models/models.dart';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:bitclass/features/quizzes/presentation/screens/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('student results show status without answer details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_student));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

    final quizRepository = _FakeQuizRepository();
    addTearDown(() async {
      quizRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<QuizRepository>.value(
        value: quizRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: QuizScreen(courseId: 'course-1', quizId: 'quiz-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Posted: Aug 28, 2026 at 12:18 PM'), findsOneWidget);
    await tester.tap(find.text('Take Quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaked selected option'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pumpAndSettle();

    final resultItem = find.byKey(
      const ValueKey('student-quiz-result-question-1'),
    );

    expect(find.text('Quiz Results'), findsOneWidget);
    expect(resultItem, findsOneWidget);
    expect(
      find.descendant(of: resultItem, matching: find.text('Question 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultItem, matching: find.text('Incorrect')),
      findsOneWidget,
    );
    expect(find.text(_question.questionText), findsNothing);
    expect(find.text('Secret correct option'), findsNothing);
    expect(find.text('Leaked selected option'), findsNothing);
    expect(
      find.textContaining('Expected: Secret correct option'),
      findsNothing,
    );
    expect(find.textContaining('Correct answer'), findsNothing);
  });
}

final _student = UserModel(
  id: 'student-1',
  email: 'student@example.com',
  firstName: 'Student',
  lastName: 'Learner',
  role: 'student',
  createdAt: DateTime.utc(2026, 8, 26),
);

final _quiz = QuizModel(
  id: 'quiz-1',
  courseId: 'course-1',
  title: 'Private Results Quiz',
  totalPoints: 1,
  questionCount: 1,
  showCorrectAnswers: true,
  isPublished: true,
  createdAt: DateTime(2026, 8, 28, 12, 18),
);

const _question = QuestionModel(
  id: 'question-1',
  quizId: 'quiz-1',
  type: QuestionType.multipleChoice,
  questionText: 'Which answer must not appear in student results?',
  options: [
    AnswerOptionModel(
      id: 'correct-option',
      text: 'Secret correct option',
      isCorrect: true,
    ),
    AnswerOptionModel(id: 'selected-option', text: 'Leaked selected option'),
  ],
  correctAnswers: ['correct-option'],
  explanation: 'This explanation is part of the private answer key.',
  points: 1,
);

final _startedAttempt = QuizAttemptModel(
  id: 'attempt-1',
  quizId: 'quiz-1',
  userId: 'student-1',
  startedAt: DateTime.utc(2026, 8, 26, 10),
  totalPoints: 1,
);

final _gradedAttempt = _startedAttempt.copyWith(
  status: AttemptStatus.graded,
  submittedAt: DateTime.utc(2026, 8, 26, 10, 1),
  gradedAt: DateTime.utc(2026, 8, 26, 10, 1),
  answers: {
    'question-1': UserAnswerModel(
      questionId: 'question-1',
      selectedAnswers: const ['selected-option'],
      textAnswer: 'Leaked student answer text',
      isCorrect: false,
      pointsEarned: 0,
      maxPoints: 1,
      feedback: 'Incorrect. Expected: Secret correct option',
      answeredAt: DateTime.utc(2026, 8, 26, 10, 0, 30),
    ),
  },
);

class _FakeQuizRepository extends QuizRepository {
  final SupabaseClient _client;

  factory _FakeQuizRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeQuizRepository._(client);
  }

  _FakeQuizRepository._(this._client) : super(supabase: _client);

  @override
  Future<QuizModel?> getQuiz(String quizId) async => _quiz;

  @override
  Future<List<QuestionModel>> getQuestions(String quizId) async => [_question];

  @override
  Future<List<QuizAttemptModel>> getAttempts({
    required String quizId,
    required String userId,
  }) async => const [];

  @override
  Future<QuizAvailability> getQuizAvailability(String quizId) async =>
      QuizAvailability(serverNow: DateTime.utc(2026, 8, 28), isClosed: false);

  @override
  Future<QuizAttemptModel> startAttempt({
    required String quizId,
    required String userId,
    String? enrollmentId,
  }) async => _startedAttempt;

  @override
  Future<QuizAttemptModel> saveAnswer({
    required String attemptId,
    required String questionId,
    List<String>? selectedAnswers,
    String? textAnswer,
    String? codeAnswer,
  }) async => _startedAttempt.copyWith(
    answers: {
      questionId: UserAnswerModel(
        questionId: questionId,
        selectedAnswers: selectedAnswers ?? const [],
        textAnswer: textAnswer,
        codeAnswer: codeAnswer,
        answeredAt: DateTime.utc(2026, 8, 26, 10, 0, 30),
      ),
    },
  );

  @override
  Future<QuizAttemptModel> submitAttempt(String attemptId) async =>
      _gradedAttempt;

  void dispose() => _client.auth.dispose();
}

class _FakeAuthRepository extends AuthRepository {
  final SupabaseClient _client;
  final StreamController<User?> _authController =
      StreamController<User?>.broadcast();

  factory _FakeAuthRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeAuthRepository._(client);
  }

  _FakeAuthRepository._(this._client) : super(supabase: _client);

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  Future<void> dispose() async {
    _client.auth.dispose();
    await _authController.close();
  }
}
