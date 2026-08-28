import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitclass/features/assignments/data/models/models.dart';
import 'package:bitclass/features/assignments/data/repositories/assignment_repository.dart';
import 'package:bitclass/features/quizzes/data/models/models.dart';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'quiz creation lets the database assign the original timestamp',
    () async {
      final fixture = await _PostgrestFixture.start();
      addTearDown(fixture.close);
      final repository = QuizRepository(supabase: fixture.client);

      await repository.createQuiz(
        QuizModel(
          id: 'quiz-1',
          courseId: 'course-1',
          title: 'Database timestamp quiz',
          createdAt: DateTime.utc(2000),
        ),
      );

      final request = await fixture.nextRequest;
      expect(request.path, '/rest/v1/quizzes');
      expect(request.body, isNot(contains('created_at')));
      expect(request.body, isNot(contains('updated_at')));
    },
  );

  test('activity creation returns the database creation timestamp', () async {
    final fixture = await _PostgrestFixture.start(
      responseForPath: {'/rest/v1/assignments': _assignmentRow},
    );
    addTearDown(fixture.close);
    final repository = AssignmentRepository(supabase: fixture.client);

    final created = await repository.createAssignment(
      AssignmentModel(
        id: 'assignment-1',
        courseId: 'course-1',
        title: 'Database timestamp activity',
        description: 'Created by the instructor.',
        language: ProgrammingLanguage.plaintext,
        maxPoints: 25,
        isPublished: true,
        createdAt: DateTime.utc(2000),
      ),
    );

    final request = await fixture.nextRequest;
    expect(request.path, '/rest/v1/assignments');
    expect(request.body, isNot(contains('created_at')));
    expect(created.createdAt, DateTime.parse(_databaseCreatedAt));
  });
}

const _databaseCreatedAt = '2026-08-28T04:18:00.000Z';

const _assignmentRow = <String, dynamic>{
  'id': 'assignment-1',
  'course_id': 'course-1',
  'lesson_id': null,
  'title': 'Database timestamp activity',
  'description': 'Created by the instructor.',
  'instructions': null,
  'language': 'plaintext',
  'starter_code': null,
  'solution_code': null,
  'attachments': <dynamic>[],
  'requires_attachment': false,
  'max_points': 25,
  'grading_criteria': <dynamic>[],
  'due_date': null,
  'allow_late_submission': true,
  'late_penalty_percent': 10,
  'is_published': true,
  'created_at': _databaseCreatedAt,
  'updated_at': _databaseCreatedAt,
};

typedef _CapturedRequest = ({String path, Map<String, dynamic> body});

class _PostgrestFixture {
  final HttpServer _server;
  final StreamSubscription<HttpRequest> _subscription;
  final Completer<_CapturedRequest> _requestCompleter;
  final SupabaseClient client;

  _PostgrestFixture._(
    this._server,
    this._subscription,
    this._requestCompleter,
    this.client,
  );

  Future<_CapturedRequest> get nextRequest => _requestCompleter.future;

  static Future<_PostgrestFixture> start({
    Map<String, Object> responseForPath = const {},
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestCompleter = Completer<_CapturedRequest>();
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      final decoded = jsonDecode(await utf8.decoder.bind(request).join());
      if (!requestCompleter.isCompleted) {
        requestCompleter.complete((
          path: request.uri.path,
          body: Map<String, dynamic>.from(decoded as Map),
        ));
      }

      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(responseForPath[request.uri.path] ?? const []));
      await request.response.close();
    });

    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'test-anon-key',
    );
    client.auth.stopAutoRefresh();
    return _PostgrestFixture._(server, subscription, requestCompleter, client);
  }

  Future<void> close() async {
    client.auth.dispose();
    await _subscription.cancel();
    await _server.close(force: true);
  }
}
