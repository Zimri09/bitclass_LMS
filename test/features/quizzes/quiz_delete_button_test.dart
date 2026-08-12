import 'package:bitclass/features/quizzes/data/models/quiz_model.dart';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:bitclass/features/quizzes/presentation/widgets/quiz_delete_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('quiz deletion requires explicit confirmation', (tester) async {
    final repository = _FakeQuizRepository();
    addTearDown(repository.dispose);
    var deletedCallbacks = 0;

    await tester.pumpWidget(
      RepositoryProvider<QuizRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: QuizDeleteButton(
              quiz: _quiz,
              onDeleted: () => deletedCallbacks++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('delete-quiz-quiz-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete quiz?'), findsOneWidget);
    expect(find.textContaining('Generated Quiz'), findsOneWidget);
    expect(
      find.textContaining('student answers, and attempts'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deletedQuizIds, isEmpty);
    expect(deletedCallbacks, 0);

    await tester.tap(find.byKey(const ValueKey('delete-quiz-quiz-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-quiz-quiz-1')));
    await tester.pumpAndSettle();

    expect(repository.deletedQuizIds, ['quiz-1']);
    expect(deletedCallbacks, 1);
    expect(find.text('Quiz deleted successfully.'), findsOneWidget);
  });

  testWidgets('failed quiz deletion keeps the quiz and reports an error', (
    tester,
  ) async {
    final repository = _FakeQuizRepository(shouldFail: true);
    addTearDown(repository.dispose);
    var deletedCallbacks = 0;

    await tester.pumpWidget(
      RepositoryProvider<QuizRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: QuizDeleteButton(
              quiz: _quiz,
              onDeleted: () => deletedCallbacks++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('delete-quiz-quiz-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Quiz'));
    await tester.pumpAndSettle();

    expect(repository.deletedQuizIds, ['quiz-1']);
    expect(deletedCallbacks, 0);
    expect(find.textContaining('Failed to delete quiz'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-quiz-quiz-1')), findsOneWidget);
  });
}

final _quiz = QuizModel(
  id: 'quiz-1',
  courseId: 'course-1',
  title: 'Generated Quiz',
  questionCount: 10,
  totalPoints: 20,
  createdAt: DateTime.utc(2026, 8, 12),
);

class _FakeQuizRepository extends QuizRepository {
  final SupabaseClient _client;
  final bool shouldFail;
  final List<String> deletedQuizIds = [];

  factory _FakeQuizRepository({bool shouldFail = false}) {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeQuizRepository._(client, shouldFail);
  }

  _FakeQuizRepository._(this._client, this.shouldFail)
    : super(supabase: _client);

  @override
  Future<void> deleteQuiz(String quizId) async {
    deletedQuizIds.add(quizId);
    if (shouldFail) throw StateError('Quiz was not deleted.');
  }

  void dispose() {
    _client.auth.dispose();
  }
}
