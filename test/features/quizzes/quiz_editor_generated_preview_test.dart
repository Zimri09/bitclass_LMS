import 'dart:async';
import 'dart:typed_data';

import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/quizzes/data/models/question_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_generation_model.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_model.dart';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:bitclass/features/quizzes/presentation/screens/quiz_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'pending generation can be cancelled and back remains actionable',
    (tester) async {
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
            child: _quizEditorNavigationApp(sourcePicker: _pickTestSource),
          ),
        ),
      );
      await tester.tap(find.text('Open Quiz Editor'));
      await tester.pumpAndSettle();

      await _startGeneration(tester);
      expect(find.text('Cancel Generation'), findsOneWidget);
      expect(quizRepository.generationRequests, hasLength(1));

      await tester.tap(find.text('Cancel Generation'));
      await tester.pump();
      expect(find.text('Generate Draft Questions'), findsOneWidget);
      expect(find.text('Questions (0)'), findsOneWidget);

      quizRepository.generationRequests.first.complete([_question]);
      await tester.pump();
      expect(find.text('Questions (0)'), findsOneWidget);
      expect(find.text('Questions (1)'), findsNothing);

      await _startGeneration(tester, chooseFile: false);
      expect(quizRepository.generationRequests, hasLength(2));

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave quiz editor?'), findsOneWidget);
      expect(
        find.textContaining('Question generation is still running'),
        findsOneWidget,
      );

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open Quiz Editor'), findsOneWidget);

      quizRepository.generationRequests.last.completeError(
        const QuizGenerationException('Late failure'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation failure restores controls and allows retry', (
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
          child: MaterialApp(
            home: QuizEditorScreen(
              courseId: 'course-1',
              sourcePicker: _pickTestSource,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _startGeneration(tester);
    quizRepository.generationRequests.single.completeError(
      const QuizGenerationException(
        'Question generation timed out. Try fewer questions.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cancel Generation'), findsNothing);
    expect(find.text('Generate Draft Questions'), findsOneWidget);
    expect(
      find.textContaining('Question generation timed out'),
      findsOneWidget,
    );

    await tester.tap(find.text('Generate Draft Questions'));
    await tester.pump();
    expect(quizRepository.generationRequests, hasLength(2));
    expect(find.text('Cancel Generation'), findsOneWidget);

    await tester.tap(find.text('Cancel Generation'));
    await tester.pump();
  });

  testWidgets('back navigation warns before discarding quiz work', (
    tester,
  ) async {
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
          child: _quizEditorNavigationApp(),
        ),
      ),
    );
    await tester.tap(find.text('Open Quiz Editor'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave quiz editor?'), findsOneWidget);
    expect(find.text('Keep Editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Save as Draft'), findsOneWidget);

    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.text('Create Quiz'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Open Quiz Editor'), findsOneWidget);
    expect(quizRepository.createdQuiz, isNull);
    expect(quizRepository.savedQuestions, isEmpty);
  });

  testWidgets('unfinished quiz work can be saved as a draft when leaving', (
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
          child: _quizEditorNavigationApp(),
        ),
      ),
    );
    await tester.tap(find.text('Open Quiz Editor'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add Question'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add Question'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Open Quiz Editor'), findsOneWidget);
    expect(quizRepository.createdQuiz, isNotNull);
    expect(quizRepository.createdQuiz!.title, 'Untitled Quiz Draft');
    expect(quizRepository.createdQuiz!.isPublished, isFalse);
    expect(quizRepository.createdQuiz!.questionCount, 1);
    expect(quizRepository.createdQuiz!.timeLimitMinutes, 15);
    expect(quizRepository.createdQuiz!.passingScore, 50);
    expect(quizRepository.createdQuiz!.maxAttempts, 1);
    expect(quizRepository.savedQuestions, hasLength(1));
    expect(
      quizRepository.savedQuestions.single.quizId,
      quizRepository.createdQuiz!.id,
    );
  });

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

    expect(find.text('Edit Quiz'), findsOneWidget);
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
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);

    final mobileEditor = find.byKey(
      const ValueKey('question-1-scrollable-editor'),
    );
    final editorScrollable = find
        .descendant(of: mobileEditor, matching: find.byType(Scrollable))
        .first;
    expect(mobileEditor, findsOneWidget);
    expect(editorScrollable, findsOneWidget);

    await tester.ensureVisible(mobileEditor);
    await tester.pumpAndSettle();
    final scrollableState = tester.state<ScrollableState>(editorScrollable);
    expect(scrollableState.position.maxScrollExtent, greaterThan(0));

    await tester.drag(editorScrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrollableState.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'file generation offers short answers and points by question type',
    (tester) async {
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
              home: QuizEditorScreen(courseId: 'course-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Generate from File'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Generate from File'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('generation-multipleChoice-points')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('generation-trueFalse-points')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('generation-shortAnswer-points')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('generation-question-type')));
      await tester.pumpAndSettle();
      expect(find.text('Short Answer'), findsOneWidget);

      await tester.tap(find.text('Short Answer'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('generation-multipleChoice-points')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('generation-trueFalse-points')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('generation-shortAnswer-points')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generated short answers remain editable', (tester) async {
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

    final quizRepository = _FakeQuizRepository(question: _shortQuestion);
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

    await tester.scrollUntilVisible(
      find.text(_shortQuestion.questionText),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(_shortQuestion.questionText));
    await tester.pumpAndSettle();

    final acceptedAnswers = find.byKey(
      const ValueKey('question-short-accepted-answers'),
    );
    expect(acceptedAnswers, findsOneWidget);
    expect(find.text('First in, first out'), findsOneWidget);

    await tester.enterText(acceptedAnswers, 'First in, first out\nFIFO');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _startGeneration(
  WidgetTester tester, {
  bool chooseFile = true,
}) async {
  final scrollable = find.byType(Scrollable).first;
  if (chooseFile) {
    await tester.scrollUntilVisible(
      find.text('Generate from File'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Generate from File'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Choose'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
  }

  final action = find.byKey(const ValueKey('quiz-generation-action'));
  await tester.scrollUntilVisible(action, 300, scrollable: scrollable);
  await tester.tap(action);
  await tester.pump();
}

Future<QuizSourceDocument?> _pickTestSource() async {
  return QuizSourceDocument(
    name: 'course-notes.txt',
    bytes: Uint8List.fromList(List<int>.filled(512, 65)),
  );
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

const _shortQuestion = QuestionModel(
  id: 'question-short',
  quizId: 'quiz-1',
  type: QuestionType.shortAnswer,
  questionText: 'Which ordering does a queue use?',
  correctAnswers: ['First in, first out'],
  explanation: 'Queue items leave in the order they entered.',
  points: 3,
);

Widget _quizEditorNavigationApp({QuizSourcePicker? sourcePicker}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QuizEditorScreen(
                  courseId: 'course-1',
                  sourcePicker: sourcePicker,
                ),
              ),
            ),
            child: const Text('Open Quiz Editor'),
          ),
        ),
      ),
    ),
  );
}

class _FakeQuizRepository extends QuizRepository {
  final SupabaseClient _client;
  final QuestionModel question;
  QuizModel? createdQuiz;
  QuizModel? updatedQuiz;
  final List<QuestionModel> savedQuestions = [];
  final List<Completer<List<QuestionModel>>> generationRequests = [];

  factory _FakeQuizRepository({QuestionModel question = _question}) {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeQuizRepository._(client, question);
  }

  _FakeQuizRepository._(this._client, this.question) : super(supabase: _client);

  @override
  Future<QuizModel?> getQuiz(String quizId) async => _quiz;

  @override
  Future<List<QuestionModel>> getQuestions(String quizId) async => [question];

  @override
  Future<void> createQuiz(QuizModel quiz) async {
    createdQuiz = quiz;
  }

  @override
  Future<void> updateQuiz(QuizModel quiz) async {
    updatedQuiz = quiz;
  }

  @override
  Future<void> saveQuestion(QuestionModel question) async {
    savedQuestions.add(question);
  }

  @override
  Future<List<QuestionModel>> generateQuestionsFromFile({
    required String courseId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required int questionCount,
    required QuizGenerationQuestionType questionType,
    required QuizGenerationDifficulty difficulty,
    required QuizGenerationPoints points,
    String? instructions,
  }) {
    final request = Completer<List<QuestionModel>>();
    generationRequests.add(request);
    return request.future;
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
