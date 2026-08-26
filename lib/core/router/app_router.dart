import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/assignments/presentation/screens/screens.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/startup_screen.dart';
import '../../features/todos/presentation/screens/todos_list_screen.dart';
import '../../features/todos/presentation/state/todos_cubit.dart';
import '../../features/todos/data/repositories/todos_repository.dart';
import '../../features/todos/data/models/todo_model.dart';

import '../../features/courses/presentation/screens/classroom_landing_screen.dart';
import '../../features/code_lab/presentation/screens/screens.dart';
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
import '../../features/settings/presentation/screens/about_bitclass_screen.dart';
import '../../features/settings/presentation/screens/help_center_screen.dart';
import '../../features/settings/presentation/screens/legal_document_screen.dart';
import '../../features/settings/presentation/screens/support_request_screen.dart';
import '../../features/settings/presentation/screens/admin_support_inbox_screen.dart';
import '../../features/settings/data/models/support_request.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';
import 'app_transitions.dart';

/// Application router configuration using GoRouter
class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.startup,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        name: 'startup',
        builder: (context, state) => const StartupScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.verifyOtp,
        name: 'verify-otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
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
              child: const ClassroomLandingScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.todos,
            name: 'todos',
            pageBuilder: (context, state) {
              final authState = context.read<AuthBloc>().state;
              final audience =
                  authState is AuthAuthenticated && authState.user.isStaff
                  ? TodoAudience.instructor
                  : TodoAudience.student;
              return AppTransitions.fadeTransition(
                context: context,
                state: state,
                child: BlocProvider<TodosCubit>(
                  create: (context) => TodosCubit(
                    todosRepository: TodosRepository(),
                    audience: audience,
                  )..load(),
                  child: TodosListScreen(audience: audience),
                ),
              );
            },
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
            path: AppRoutes.offlineFiles,
            name: 'offline-files',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const OfflineFilesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.codeLab,
            name: 'code-lab',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const CodeLabScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.courses,
            name: 'courses',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const ClassroomLandingScreen(),
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
            path: AppRoutes.editQuiz,
            name: 'edit-quiz',
            pageBuilder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final quizId = state.pathParameters['quizId']!;
              return AppTransitions.slideFromBottom(
                context: context,
                state: state,
                child: QuizEditorScreen(courseId: courseId, quizId: quizId),
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
                child: UploadFileScreen(
                  courseId: courseId,
                  lessonId: state.uri.queryParameters['lessonId'],
                ),
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
          GoRoute(
            path: AppRoutes.settingsHelp,
            name: 'settings-help',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const HelpCenterScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settingsFeedback,
            name: 'settings-feedback',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const SupportRequestScreen(
                type: SupportRequestType.feedback,
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.settingsBugReport,
            name: 'settings-bug-report',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const SupportRequestScreen(type: SupportRequestType.bug),
            ),
          ),
          GoRoute(
            path: AppRoutes.settingsAbout,
            name: 'settings-about',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const AboutBitClassScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settingsTerms,
            name: 'settings-terms',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const LegalDocumentScreen(document: LegalDocument.terms),
            ),
          ),
          GoRoute(
            path: AppRoutes.settingsPrivacy,
            name: 'settings-privacy',
            pageBuilder: (context, state) => AppTransitions.slideFromRight(
              context: context,
              state: state,
              child: const LegalDocumentScreen(document: LegalDocument.privacy),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminSupport,
            name: 'admin-support',
            pageBuilder: (context, state) => AppTransitions.fadeTransition(
              context: context,
              state: state,
              child: const AdminSupportInboxScreen(),
            ),
          ),
        ],
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final authState = authBloc.state;
    final isStartupRoute = state.matchedLocation == AppRoutes.startup;
    final isAuthRoute =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register ||
        state.matchedLocation == AppRoutes.forgotPassword ||
        state.matchedLocation == AppRoutes.verifyOtp ||
        state.matchedLocation == AppRoutes.resetPassword;

    final isRestoringSession =
        authState is AuthInitial ||
        (authState is AuthLoading &&
            authState.operation == AuthOperation.checkingSession);

    if (isRestoringSession) {
      return isStartupRoute ? null : AppRoutes.startup;
    }

    if (authState is AuthAuthenticated && (isStartupRoute || isAuthRoute)) {
      return AppRoutes.dashboard;
    }

    if (authState is! AuthAuthenticated && isStartupRoute) {
      return AppRoutes.login;
    }

    // If not authenticated and not on an auth route, redirect to login
    if (authState is! AuthAuthenticated && !isAuthRoute) {
      return AppRoutes.login;
    }

    if (authState is AuthAuthenticated && !_canManageCourse(authState)) {
      if (_isInstructorOnlyPath(state.uri.path)) return AppRoutes.dashboard;
    }

    if (authState is AuthAuthenticated &&
        !authState.user.isAdmin &&
        state.uri.path == AppRoutes.adminSupport) {
      return AppRoutes.dashboard;
    }

    if (authState is AuthAuthenticated &&
        authState.isOffline &&
        state.matchedLocation == AppRoutes.codeLab) {
      return AppRoutes.dashboard;
    }

    return null;
  }

  bool _canManageCourse(AuthAuthenticated authState) {
    return authState.user.isStaff;
  }

  bool _isInstructorOnlyPath(String path) {
    return [
      RegExp(r'^/courses/create$'),
      RegExp(r'^/courses/[^/]+/edit$'),
      RegExp(r'^/courses/[^/]+/students$'),
      RegExp(r'^/courses/[^/]+/lessons/create$'),
      RegExp(r'^/courses/[^/]+/lessons/[^/]+/edit$'),
      RegExp(r'^/courses/[^/]+/quizzes/create$'),
      RegExp(r'^/courses/[^/]+/quizzes/[^/]+/edit$'),
      RegExp(r'^/courses/[^/]+/assignments/create$'),
      RegExp(r'^/courses/[^/]+/assignments/[^/]+/edit$'),
      RegExp(r'^/courses/[^/]+/assignments/[^/]+/grade$'),
      RegExp(r'^/courses/[^/]+/files/upload$'),
    ].any((pattern) => pattern.hasMatch(path));
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
