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
  testWidgets('instructors can preview questions without creating an attempt', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
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
    expect(find.text('Instructor preview mode'), findsOneWidget);

    await tester.tap(find.text('Instructor preview mode'));
    await tester.pumpAndSettle();

    expect(
      find.text('Previewing quiz questions only. No answers will be saved.'),
      findsOneWidget,
    );
    expect(find.text(_question.questionText), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('Back to Overview'), findsOneWidget);
    expect(quizRepository.startAttemptCalls, 0);
  });
}

final _instructor = UserModel(
  id: 'instructor-1',
  email: 'instructor@example.com',
  firstName: 'Instructor',
  lastName: 'Teacher',
  role: 'instructor',
  createdAt: DateTime.utc(2026, 8, 8),
);

final _quiz = QuizModel(
  id: 'quiz-1',
  courseId: 'course-1',
  title: 'Generated Quiz',
  description: 'Review AI-generated questions before publishing.',
  totalPoints: 1,
  questionCount: 1,
  createdAt: DateTime(2026, 8, 28, 12, 18),
);

const _question = QuestionModel(
  id: 'question-1',
  quizId: 'quiz-1',
  type: QuestionType.multipleChoice,
  questionText: 'What is the official designation?',
  options: [
    AnswerOptionModel(id: 'option-1', text: 'Alpha', isCorrect: true),
    AnswerOptionModel(id: 'option-2', text: 'Beta'),
    AnswerOptionModel(id: 'option-3', text: 'Gamma'),
    AnswerOptionModel(id: 'option-4', text: 'Delta'),
  ],
  correctAnswers: ['option-1'],
  explanation: 'The source identifies Alpha as the official designation.',
  points: 1,
);

class _FakeQuizRepository extends QuizRepository {
  final SupabaseClient _client;
  int startAttemptCalls = 0;

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
  Future<QuizAttemptModel> startAttempt({
    required String quizId,
    required String userId,
    String? enrollmentId,
  }) async {
    startAttemptCalls += 1;
    return super.startAttempt(
      quizId: quizId,
      userId: userId,
      enrollmentId: enrollmentId,
    );
  }

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
