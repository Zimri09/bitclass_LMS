import 'dart:io';
import 'package:bitclass/features/assignments/data/repositories/assignment_repository.dart';
import 'package:bitclass/features/attendance/data/repositories/attendance_repository.dart';
import 'package:bitclass/features/courses/data/repositories/course_repository.dart';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'preview queries are read-only and filter the selected student and parent',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Uri>[];
      final subscription = server.listen((request) async {
        expect(request.method, 'GET');
        requests.add(request.uri);
        request.response.headers.contentType = ContentType.json;
        request.response.write('[]');
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      addTearDown(() async {
        await client.dispose();
        await subscription.cancel();
        await server.close(force: true);
      });
      await QuizRepository(
        supabase: client,
      ).getQuizAttempts('quiz-1', studentId: 'student-1', throwOnError: true);
      await AssignmentRepository(supabase: client).getAssignmentSubmissions(
        'activity-1',
        studentId: 'student-1',
        throwOnError: true,
      );
      await AttendanceRepository(
        supabase: client,
      ).getCourseRecords('course-1', studentId: 'student-1');
      expect(requests[0].queryParameters['quiz_id'], 'eq.quiz-1');
      expect(requests[0].queryParameters['user_id'], 'eq.student-1');
      expect(requests[1].queryParameters['assignment_id'], 'eq.activity-1');
      expect(requests[1].queryParameters['user_id'], 'eq.student-1');
      expect(requests[2].queryParameters['course_id'], 'eq.course-1');
      expect(requests[2].queryParameters['student_id'], 'eq.student-1');
    },
  );

  test('signed-out sessions cannot load an instructor preview', () async {
    final client = SupabaseClient('http://127.0.0.1:1', 'test-key');
    addTearDown(client.dispose);
    await expectLater(
      CourseRepository(
        supabase: client,
      ).requireCourseInstructor('course', 'teacher'),
      throwsStateError,
    );
  });

  test(
    'failed preview queries propagate errors instead of empty scores',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = 403;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"message":"Access denied","code":"42501"}');
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      addTearDown(() async {
        await client.dispose();
        await subscription.cancel();
        await server.close(force: true);
      });
      await expectLater(
        QuizRepository(
          supabase: client,
        ).getQuizAttempts('quiz', studentId: 'student', throwOnError: true),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        AssignmentRepository(supabase: client).getAssignmentSubmissions(
          'activity',
          studentId: 'student',
          throwOnError: true,
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
