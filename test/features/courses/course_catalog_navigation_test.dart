import 'dart:async';

import 'package:bitclass/core/router/app_routes.dart';
import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/courses/data/repositories/course_repository.dart';
import 'package:bitclass/features/courses/presentation/bloc/course_bloc.dart';
import 'package:bitclass/features/courses/presentation/screens/classroom_landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'admin uses the instructor class list with controls and pull-to-refresh',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authRepository = _FakeAuthRepository();
      final authBloc = AuthBloc(authRepository: authRepository)
        ..add(AuthUserUpdated(_admin));
      await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

      final courseRepository = _FakeCourseRepository();
      addTearDown(courseRepository.dispose);
      addTearDown(() async {
        await authBloc.close();
        await authRepository.dispose();
      });

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CourseRepository>.value(value: courseRepository),
          ],
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const MaterialApp(home: ClassroomLandingScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teaching'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.text('Search your classes...'), findsNothing);
      expect(find.text('Join class'), findsNothing);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      expect(courseRepository.getInstructorCoursesCalls, 1);
    },
  );

  testWidgets(
    'student courses remain visible and reload after returning from a course',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authRepository = _FakeAuthRepository();
      final authBloc = AuthBloc(authRepository: authRepository)
        ..add(AuthUserUpdated(_student));
      await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

      final courseRepository = _FakeCourseRepository();
      final globalCourseBloc = CourseBloc(courseRepository: courseRepository);
      final router = GoRouter(
        initialLocation: AppRoutes.dashboard,
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const ClassroomLandingScreen(),
          ),
          GoRoute(
            path: AppRoutes.courseDetail,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Course detail'))),
          ),
        ],
      );

      addTearDown(router.dispose);
      addTearDown(globalCourseBloc.close);
      addTearDown(courseRepository.dispose);
      addTearDown(() async {
        await authBloc.close();
        await authRepository.dispose();
      });

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CourseRepository>.value(value: courseRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<CourseBloc>.value(value: globalCourseBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_course.title), findsOneWidget);
      expect(courseRepository.getCoursesCalls, 1);

      await tester.tap(find.text(_course.title));
      await tester.pumpAndSettle();
      expect(find.text('Course detail'), findsOneWidget);

      globalCourseBloc.add(const LoadCourseDetail('course-1'));
      await globalCourseBloc.stream.firstWhere(
        (state) => state is CourseDetailLoaded,
      );

      router.pop();
      await tester.pumpAndSettle();

      expect(courseRepository.getCoursesCalls, 2);
      expect(find.text(_course.title), findsOneWidget);
      expect(authBloc.state, AuthAuthenticated(_student));

      courseRepository.completeRefresh();
      await tester.pumpAndSettle();
      expect(find.text(_course.title), findsOneWidget);
    },
  );
}

final _student = UserModel(
  id: 'student-1',
  email: 'student@example.com',
  firstName: 'Test',
  lastName: 'Student',
  role: 'student',
  createdAt: DateTime.utc(2026, 8, 8),
);

final _admin = UserModel(
  id: 'instructor-1',
  email: 'admin@example.com',
  firstName: 'Test',
  lastName: 'Admin',
  role: 'admin',
  createdAt: DateTime.utc(2026, 8, 18),
);

final _course = CourseModel(
  id: 'course-1',
  title: 'Algorithms 101',
  description: 'Core algorithm concepts',
  category: 'Algorithms',
  instructorId: 'instructor-1',
  instructorName: 'Instructor Teacher',
  isPublished: true,
  createdAt: DateTime.utc(2026, 8, 8),
);

class _FakeCourseRepository extends CourseRepository {
  final SupabaseClient _client;
  final Completer<List<CourseModel>> _refreshCompleter = Completer();
  int getCoursesCalls = 0;
  int getInstructorCoursesCalls = 0;

  factory _FakeCourseRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeCourseRepository._(client);
  }

  _FakeCourseRepository._(this._client) : super(supabase: _client);

  @override
  Future<List<CourseModel>> getCourses({
    String? category,
    String? searchQuery,
    int limit = 20,
    Object? startAfter,
  }) {
    getCoursesCalls++;
    if (getCoursesCalls == 2) {
      return _refreshCompleter.future;
    }
    return Future.value([_course]);
  }

  @override
  Future<CourseModel?> getCourse(String courseId) async => _course;

  @override
  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    getInstructorCoursesCalls++;
    return [_course];
  }

  @override
  Stream<List<CourseModel>> watchInstructorCourses(String instructorId) =>
      Stream.value([_course]);

  @override
  Stream<CourseModel?> watchCourse(String courseId) => Stream.value(_course);

  void completeRefresh() {
    if (!_refreshCompleter.isCompleted) {
      _refreshCompleter.complete([_course]);
    }
  }

  void dispose() {
    completeRefresh();
    _client.auth.dispose();
  }
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
