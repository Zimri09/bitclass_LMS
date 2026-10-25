import 'dart:async';

import 'package:bitclass/features/assignments/data/models/criterion_score.dart';
import 'package:bitclass/features/assignments/data/models/submission_model.dart';
import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/grades/data/models/grade_model.dart';
import 'package:bitclass/features/grades/data/repositories/grade_repository.dart';
import 'package:bitclass/features/grades/presentation/bloc/grades_bloc.dart';
import 'package:bitclass/features/grades/presentation/screens/grades_screen.dart';
import 'package:bitclass/features/quizzes/data/models/quiz_attempt_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('course selection isolates every tab on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpGrades(tester, _FakeGradeRepository(_multipleCourses));

    expect(find.text('Total points: 32 / 35'), findsOneWidget);
    await tester.tap(find.text('Quizzes'));
    await tester.pumpAndSettle();
    expect(find.text('Course quiz'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('15/20'), findsNothing);

    await _selectCourse(tester, 'Mathematics');
    expect(find.text('15/20'), findsOneWidget);
    expect(find.text('8/10'), findsNothing);
    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
    expect(find.text('12/25'), findsOneWidget);
    expect(find.text('24/25'), findsNothing);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Total points: 27 / 45'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);

    await _selectCourse(tester, 'Programming 101');
    expect(find.text('Total points: 32 / 35'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh updates scores and retains the selected course', (
    tester,
  ) async {
    final repository = _FakeGradeRepository(_multipleCourses);
    await _pumpGrades(tester, repository);
    await _selectCourse(tester, 'Mathematics');
    final selected = _multipleCourses.courseGrades.last;
    repository.summary = _multipleCourses.copyWith(
      courseGrades: [
        _multipleCourses.courseGrades.first,
        selected.copyWith(
          quizAttempts: [
            selected.quizAttempts.first.copyWith(score: 20, percentage: 100),
          ],
        ),
      ],
    );
    await tester.tap(find.byTooltip('Refresh grades'));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(find.text('Total points: 32 / 45'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);

    // A removed enrollment must not leave stale grades selected.
    repository.summary = _summary;
    await tester.tap(find.byTooltip('Refresh grades'));
    await tester.pumpAndSettle();
    expect(find.text('Total points: 24 / 25'), findsOneWidget);
    expect(find.text('Mathematics'), findsNothing);
  });

  testWidgets('courses without grades and no enrollments show empty states', (
    tester,
  ) async {
    final repository = _FakeGradeRepository(
      _multipleCourses.copyWith(
        courseGrades: [
          _multipleCourses.courseGrades.first,
          _multipleCourses.courseGrades.last.copyWith(
            quizAttempts: [],
            assignmentSubmissions: [],
          ),
        ],
      ),
    );
    await _pumpGrades(tester, repository);
    await _selectCourse(tester, 'Mathematics');
    expect(find.text('Total points: 0 / 0'), findsOneWidget);
    await tester.tap(find.text('Quizzes'));
    await tester.pumpAndSettle();
    expect(find.text('No quiz grades'), findsOneWidget);
    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
    expect(find.text('No activity grades'), findsOneWidget);
    repository.summary = GradesSummaryModel(userId: _student.id);
    await tester.tap(find.byTooltip('Refresh grades'));
    await tester.pumpAndSettle();
    expect(find.text('No enrolled courses'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();

    expect(find.text('CODE YOUR PIC'), findsOneWidget);
    expect(find.text('24/25'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
    expect(find.text('24/100'), findsNothing);
    expect(find.text('24%'), findsNothing);
    expect(find.text('Criteria breakdown'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('10/10'), findsOneWidget);
    expect(find.text('Completeness'), findsOneWidget);
    expect(find.text('14/15'), findsOneWidget);
  });
}

Future<void> _pumpGrades(
  WidgetTester tester,
  _FakeGradeRepository repository,
) async {
  final authRepository = _FakeAuthRepository();
  final authBloc = AuthBloc(authRepository: authRepository)
    ..add(AuthUserUpdated(_student));
  await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
  final gradesBloc = GradesBloc(gradeRepository: repository);
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
}

Future<void> _selectCourse(WidgetTester tester, String title) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}

final _multipleCourses = GradesSummaryModel(
  userId: _student.id,
  courseGrades: [
    _summary.courseGrades.first.copyWith(
      quizTitles: const {'quiz-1': 'Course quiz'},
      quizAttempts: [
        QuizAttemptModel(
          id: 'attempt-1',
          quizId: 'quiz-1',
          userId: _student.id,
          startedAt: DateTime.utc(2026, 8, 18),
          status: AttemptStatus.graded,
          score: 8,
          totalPoints: 10,
          percentage: 80,
        ),
      ],
    ),
    CourseGradeModel(
      courseId: 'course-2',
      userId: _student.id,
      course: _course.copyWith(id: 'course-2', title: 'Mathematics'),
      enrollment: EnrollmentModel(
        id: 'enrollment-2',
        courseId: 'course-2',
        userId: _student.id,
        enrolledAt: DateTime.utc(2026, 8, 1),
      ),
      quizTitles: const {'quiz-2': 'Course quiz'},
      quizAttempts: [
        QuizAttemptModel(
          id: 'attempt-2',
          quizId: 'quiz-2',
          userId: _student.id,
          startedAt: DateTime.utc(2026, 8, 18),
          status: AttemptStatus.graded,
          score: 15,
          totalPoints: 20,
          percentage: 75,
        ),
      ],
      assignmentSubmissions: [
        _summary.courseGrades.first.assignmentSubmissions.first.copyWith(
          id: 'submission-2',
          assignmentId: 'assignment-2',
          courseId: 'course-2',
          score: 12,
          criterionScores: [],
        ),
      ],
    ),
  ],
);

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
          criterionScores: const [
            CriterionScore(
              criterionId: 'accuracy',
              criterionName: 'Accuracy',
              maxPoints: 10,
              score: 10,
            ),
            CriterionScore(
              criterionId: 'completeness',
              criterionName: 'Completeness',
              maxPoints: 15,
              score: 14,
            ),
          ],
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
  GradesSummaryModel summary;
  int loads = 0;

  _FakeGradeRepository(this.summary);

  @override
  Future<GradesSummaryModel> getGradesSummary(String userId) async {
    loads++;
    return summary;
  }

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
