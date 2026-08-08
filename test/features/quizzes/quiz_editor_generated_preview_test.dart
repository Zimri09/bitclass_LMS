import 'dart:async';

import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/quizzes/data/models/question_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_model.dart';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:bitclass/features/quizzes/presentation/screens/quiz_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('generated question editor expands safely on a phone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

    final quizRepository = _FakeQuizRepository();
    addTearDown(quizRepository.dispose);
    addTearDown(() async {
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<QuizRepository>.value(
        value: quizRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: QuizEditorScreen(courseId: 'course-1', quizId: 'quiz-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Questions (1)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(_question.questionText),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(_question.questionText));
    await tester.pumpAndSettle();

    final typeField = find.byKey(const ValueKey('question-1-type'));
    final pointsField = find.byKey(const ValueKey('question-1-points'));
    expect(typeField, findsOneWidget);
    expect(pointsField, findsOneWidget);
    expect(
      tester.getTopLeft(pointsField).dy,
      greaterThan(tester.getBottomLeft(typeField).dy),
    );
    expect(tester.takeException(), isNull);
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
  totalPoints: 1,
  questionCount: 1,
  createdAt: DateTime.utc(2026, 8, 8),
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
