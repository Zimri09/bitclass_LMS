import 'dart:async';

import 'package:bitclass/features/assignments/data/models/submission_model.dart';
import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/grades/data/models/grade_model.dart';
import 'package:bitclass/features/grades/data/repositories/grade_repository.dart';
import 'package:bitclass/features/grades/presentation/bloc/grades_bloc.dart';
import 'package:bitclass/features/grades/presentation/screens/grades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('assignment card uses the instructor saved maximum points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_student));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

    final gradesBloc = GradesBloc(
      gradeRepository: _FakeGradeRepository(_summary),
    );
    addTearDown(gradesBloc.close);
    addTearDown(() async {
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<GradesBloc>.value(value: gradesBloc),
        ],
        child: const MaterialApp(home: GradesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assignments'));
    await tester.pumpAndSettle();

    expect(find.text('CODE YOUR PIC'), findsOneWidget);
    expect(find.text('24/25'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
    expect(find.text('24/100'), findsNothing);
    expect(find.text('24%'), findsNothing);
  });
}

final _student = UserModel(
  id: 'student-1',
  email: 'student@example.com',
  firstName: 'Student',
  lastName: 'One',
  role: 'student',
  createdAt: DateTime.utc(2026, 8, 1),
);

final _course = CourseModel(
  id: 'course-1',
  title: 'Programming 101',
  description: 'Course description',
  category: 'Programming',
  instructorId: 'instructor-1',
  instructorName: 'Instructor One',
  isPublished: true,
  createdAt: DateTime.utc(2026, 8, 1),
);

final _summary = GradesSummaryModel(
  userId: _student.id,
  courseGrades: [
    CourseGradeModel(
      courseId: _course.id,
      userId: _student.id,
      course: _course,
      enrollment: EnrollmentModel(
        id: 'enrollment-1',
        courseId: _course.id,
        userId: _student.id,
        enrolledAt: DateTime.utc(2026, 8, 1),
      ),
      assignmentSubmissions: [
        SubmissionModel(
          id: 'submission-1',
          assignmentId: 'assignment-1',
          courseId: _course.id,
          userId: _student.id,
          userDisplayName: 'Student One',
          code: '',
          status: SubmissionStatus.graded,
          score: 24,
          assignmentTitle: 'CODE YOUR PIC',
          assignmentMaxPoints: 25,
          createdAt: DateTime.utc(2026, 8, 18),
          submittedAt: DateTime.utc(2026, 8, 18),
          gradedAt: DateTime.utc(2026, 8, 19),
        ),
      ],
    ),
  ],
);

class _FakeGradeRepository implements GradeRepository {
  final GradesSummaryModel summary;

  const _FakeGradeRepository(this.summary);

  @override
  Future<GradesSummaryModel> getGradesSummary(String userId) async => summary;

  @override
  Future<CourseGradeModel?> getCourseGrade({
    required String courseId,
    required String userId,
    dynamic enrollment,
  }) async => summary.courseGrades.first;
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
