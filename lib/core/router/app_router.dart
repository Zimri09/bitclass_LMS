import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/assignments/presentation/screens/screens.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/courses/presentation/screens/course_catalog_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/create_course_screen.dart';
import '../../features/courses/presentation/screens/my_courses_screen.dart';
import '../../features/courses/presentation/screens/enrolled_courses_screen.dart';
import '../../features/courses/presentation/screens/enrolled_students_screen.dart';
import '../../features/discussions/presentation/screens/channel_list_screen.dart';
import '../../features/discussions/presentation/screens/thread_list_screen.dart';
import '../../features/discussions/presentation/screens/thread_detail_screen.dart';
import '../../features/discussions/presentation/screens/create_thread_screen.dart';
import '../../features/files/presentation/screens/screens.dart';
import '../../features/grades/presentation/screens/grades_screen.dart';
import '../../features/lessons/lessons.dart';
import '../../features/notifications/presentation/screens/screens.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/quizzes/presentation/screens/screens.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';
import 'app_transitions.dart';

/// Application router configuration using GoRouter
class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: _redirect,
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main app routes with shell
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.courses,
            name: 'courses',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const CourseCatalogScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.myCourses,
            name: 'my-courses',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const MyCoursesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.enrolledCourses,
            name: 'enrolled-courses',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const EnrolledCoursesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.createCourse,
            name: 'create-course',
            pageBuilder: (context, state) => AppTransitions.slideFromBottom(
              context: context,
              state: state,
              child: const CreateCourseScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.editCourse,
            name: 'edit-course',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: CreateCourseScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.courseStudents,
            name: 'course-students',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: EnrolledStudentsScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.courseDetail,
            name: 'course-detail',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: CourseDetailScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.createLesson,
            name: 'create-lesson',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: LessonEditorScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.lesson,
            name: 'lesson',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final lessonId = state.pathParameters['lessonId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: LessonScreen(courseId: courseId, lessonId: lessonId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.editLesson,
            name: 'edit-lesson',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final lessonId = state.pathParameters['lessonId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: LessonEditorScreen(
                  courseId: courseId,
                  lessonId: lessonId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.createQuiz,
            name: 'create-quiz',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: QuizEditorScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.quiz,
            name: 'quiz',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final quizId = state.pathParameters['quizId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: QuizScreen(courseId: courseId, quizId: quizId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.quizResult,
            name: 'quiz-result',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final quizId = state.pathParameters['quizId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: QuizScreen(courseId: courseId, quizId: quizId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.assignments,
            name: 'assignments',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: AssignmentListScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.createAssignment,
            name: 'create-assignment',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: AssignmentEditorScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.editAssignment,
            name: 'edit-assignment',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final assignmentId = state.pathParameters['assignmentId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: AssignmentEditorScreen(
                  courseId: courseId,
                  assignmentId: assignmentId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.submitAssignment,
            name: 'submit-assignment',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final assignmentId = state.pathParameters['assignmentId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: AssignmentDetailScreen(
                  courseId: courseId,
                  assignmentId: assignmentId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.gradeAssignment,
            name: 'grade-assignment',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final assignmentId = state.pathParameters['assignmentId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: GradeSubmissionScreen(
                  courseId: courseId,
                  assignmentId: assignmentId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.assignment,
            name: 'assignment',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final assignmentId = state.pathParameters['assignmentId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: AssignmentDetailScreen(
                  courseId: courseId,
                  assignmentId: assignmentId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.discussions,
            name: 'discussions',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: ChannelListScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.channel,
            name: 'channel',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final channelId = state.pathParameters['channelId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: ThreadListScreen(
                  courseId: courseId,
                  channelId: channelId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.createThread,
            name: 'create-thread',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final channelId = state.pathParameters['channelId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: CreateThreadScreen(
                  courseId: courseId,
                  channelId: channelId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.thread,
            name: 'thread',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final channelId = state.pathParameters['channelId']!;
              final threadId = state.pathParameters['threadId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: ThreadDetailScreen(
                  courseId: courseId,
                  channelId: channelId,
                  threadId: threadId,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const NotificationListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notificationSettings,
            name: 'notification-settings',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const NotificationSettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.files,
            name: 'files',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromRight(
                context: context,
                state: state,
                child: FileListScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.uploadFile,
            name: 'upload-file',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: UploadFileScreen(courseId: courseId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.grades,
            name: 'grades',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const GradesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final authState = authBloc.state;
    final isAuthRoute =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register ||
        state.matchedLocation == AppRoutes.forgotPassword;

    // If not authenticated and not on an auth route, redirect to login
    if (authState is! AuthAuthenticated && !isAuthRoute) {
      return AppRoutes.login;
    }

    // If authenticated and on an auth route, redirect to dashboard
    if (authState is AuthAuthenticated && isAuthRoute) {
      return AppRoutes.dashboard;
    }

    // Instructor-only route guard: redirect non-instructors to dashboard
    if (authState is AuthAuthenticated && authState.user.role != 'instructor') {
      const instructorPrefixes = ['/courses/create', '/courses/'];
      final loc = state.matchedLocation;
      final isCreateEdit =
          loc == '/courses/create' ||
          (loc.contains('/lessons/create') ||
              loc.contains('/lessons/') && loc.endsWith('/edit') ||
              loc.contains('/quizzes/create') ||
              loc.contains('/assignments/create') ||
              loc.contains('/assignments/') && loc.endsWith('/edit') ||
              loc.endsWith('/files/upload') ||
              loc.endsWith('/edit') &&
                  RegExp(r'/courses/[^/]+/edit$').hasMatch(loc));
      if (isCreateEdit) {
        return AppRoutes.dashboard;
      }
    }

    return null;
  }
}

/// Converts a Stream into a Listenable for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
