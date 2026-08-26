import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('live quiz flow uses the protected RPC endpoints', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <({String path, Map<String, dynamic> body})>[];
    final allRequestsReceived = Completer<void>();

    final serverSubscription = server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      requests.add((
        path: request.uri.path,
        body: Map<String, dynamic>.from(body as Map),
      ));

      final responseBody = switch (request.uri.path) {
        '/rest/v1/rpc/get_quiz_questions' => [_questionRow],
        '/rest/v1/rpc/start_quiz_attempt' => [_attemptRow],
        '/rest/v1/rpc/save_quiz_answer' => [
          {
            ..._attemptRow,
            'answers': {'question-1': _answerRow},
          },
        ],
        '/rest/v1/rpc/submit_quiz_attempt' => {
          ..._attemptRow,
          'status': 'graded',
          'submitted_at': '2026-08-25T12:01:00.000Z',
          'graded_at': '2026-08-25T12:01:00.000Z',
          'score': 2,
          'percentage': 100,
          'passed': true,
          'answers': {'question-1': _gradedAnswerRow},
        },
        _ => throw StateError('Unexpected request: ${request.uri.path}'),
      };

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(responseBody));
      await request.response.close();

      if (requests.length == 4 && !allRequestsReceived.isCompleted) {
        allRequestsReceived.complete();
      }
    });

    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'test-anon-key',
    );
    client.auth.stopAutoRefresh();
    final repository = QuizRepository(supabase: client);

    addTearDown(() async {
      client.auth.dispose();
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    final questions = await repository.getQuestions('quiz-1');
    final started = await repository.startAttempt(
      quizId: 'quiz-1',
      userId: 'user-1',
    );
    final saved = await repository.saveAnswer(
      attemptId: started.id,
      questionId: 'question-1',
      selectedAnswers: const ['opt-1'],
    );
    final submitted = await repository.submitAttempt(started.id);
    await allRequestsReceived.future;

    expect(questions, hasLength(1));
    expect(questions.single.correctAnswers, isEmpty);
    expect(questions.single.options.single.isCorrect, isFalse);
    expect(saved.answers['question-1']?.selectedAnswers, ['opt-1']);
    expect(submitted.score, 2);
    expect(submitted.passed, isTrue);

    expect(requests.map((request) => request.path), [
      '/rest/v1/rpc/get_quiz_questions',
      '/rest/v1/rpc/start_quiz_attempt',
      '/rest/v1/rpc/save_quiz_answer',
      '/rest/v1/rpc/submit_quiz_attempt',
    ]);
    expect(requests[0].body, {'p_quiz_id': 'quiz-1'});
    expect(requests[1].body, {'p_quiz_id': 'quiz-1', 'p_enrollment_id': null});
    expect(requests[2].body, {
      'p_attempt_id': 'attempt-1',
      'p_question_id': 'question-1',
      'p_selected_answers': ['opt-1'],
      'p_text_answer': null,
      'p_code_answer': null,
    });
    expect(requests[3].body, {'p_attempt_id': 'attempt-1'});
  });
}

const _questionRow = <String, dynamic>{
  'id': 'question-1',
  'quiz_id': 'quiz-1',
  'question_type': 'multipleChoice',
  'prompt': 'Choose the correct answer.',
  'points': 2,
  'options': [
    {'id': 'opt-1', 'text': 'Answer'},
  ],
  'correct_answer': null,
  'explanation': null,
  'question_code': null,
  'code_language': null,
  'hint': null,
  'test_cases': <dynamic>[],
  'sort_order': 0,
};

const _attemptRow = <String, dynamic>{
  'id': 'attempt-1',
  'quiz_id': 'quiz-1',
  'user_id': 'user-1',
  'enrollment_id': null,
  'status': 'inProgress',
  'attempt_number': 1,
  'started_at': '2026-08-25T12:00:00.000Z',
  'submitted_at': null,
  'graded_at': null,
  'score': 0,
  'total_points': 2,
  'percentage': 0,
  'passed': false,
  'time_spent_seconds': 0,
  'answers': <String, dynamic>{},
};

const _answerRow = <String, dynamic>{
  'questionId': 'question-1',
  'selectedAnswers': ['opt-1'],
  'textAnswer': null,
  'codeAnswer': null,
  'isCorrect': false,
  'pointsEarned': 0,
  'maxPoints': 2,
  'feedback': null,
  'answeredAt': '2026-08-25T12:00:30.000Z',
};

const _gradedAnswerRow = <String, dynamic>{
  'questionId': 'question-1',
  'selectedAnswers': ['opt-1'],
  'textAnswer': null,
  'codeAnswer': null,
  'isCorrect': true,
  'pointsEarned': 2,
  'maxPoints': 2,
  'feedback': 'Correct!',
  'answeredAt': '2026-08-25T12:00:30.000Z',
};
