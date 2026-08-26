import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/bloc/app_bloc_observer.dart';
import 'core/constants/app_constants.dart';
import 'core/config/environment.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/assignments/data/repositories/assignment_repository.dart';
import 'features/attendance/data/repositories/attendance_repository.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/class_records/data/repositories/class_record_repository.dart';
import 'features/code_lab/data/repositories/code_execution_repository.dart';
import 'features/courses/data/repositories/course_repository.dart';
import 'features/courses/presentation/bloc/course_bloc.dart';
import 'features/discussions/data/repositories/discussion_repository.dart';
import 'features/files/data/repositories/file_repository.dart';
import 'features/grades/data/repositories/grade_repository.dart';
import 'features/grades/presentation/bloc/grades_bloc.dart';
import 'features/lessons/data/repositories/lesson_repository.dart';
import 'features/notifications/data/repositories/notification_repository.dart';
import 'features/notifications/data/services/push_notification_service.dart';
import 'features/quizzes/data/repositories/quiz_repository.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/data/repositories/support_repository.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

/// Whether the app is running in demo mode
/// Uses the centralized EnvironmentConfig
bool get kDemoMode => EnvironmentConfig.isDemoMode;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  EnvironmentConfig.validate();

  // Load package info (version, build number)
  await AppConstants.initPackageInfo();

  // Log environment on startup
  EnvironmentConfig.logEnvironment();

  // Initialize Supabase when that backend mode is enabled.
  if (EnvironmentConfig.useSupabase) {
    try {
      await Supabase.initialize(
        url: EnvironmentConfig.supabaseUrl,
        publishableKey: EnvironmentConfig.supabasePublishableKey,
      );
      if (kDebugMode) {
        log('Supabase initialized successfully', name: 'Main');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Supabase initialization failed: $e', name: 'Main');
      }
      rethrow;
    }
  }

  final firebaseMessagingAvailable = await initializeFirebaseMessaging();

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Set up Bloc observer for debugging
  Bloc.observer = AppBlocObserver();

  runApp(BitClassApp(firebaseMessagingAvailable: firebaseMessagingAvailable));
}

class BitClassApp extends StatefulWidget {
  final bool firebaseMessagingAvailable;

  const BitClassApp({super.key, required this.firebaseMessagingAvailable});

  @override
  State<BitClassApp> createState() => _BitClassAppState();
}

class _BitClassAppState extends State<BitClassApp> {
  late final AuthRepository _authRepository;
  late final AttendanceRepository _attendanceRepository;
  late final ClassRecordRepository _classRecordRepository;
  late final CourseRepository _courseRepository;
  late final CodeExecutionRepository _codeExecutionRepository;
  late final LessonRepository _lessonRepository;
  late final QuizRepository _quizRepository;
  late final AssignmentRepository _assignmentRepository;
  late final DiscussionRepository _discussionRepository;
  late final NotificationRepository _notificationRepository;
  late final FileRepository _fileRepository;
  late final GradeRepository _gradeRepository;
  late final SettingsRepository _settingsRepository;
  late final SupportRepository _supportRepository;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;
  late final PushNotificationService _pushNotificationService;
  StreamSubscription<AuthState>? _pushAuthSubscription;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _attendanceRepository = AttendanceRepository();
    _courseRepository = CourseRepository();
    _codeExecutionRepository = SupabaseCodeExecutionRepository();
    _lessonRepository = LessonRepository();
    _quizRepository = QuizRepository();
    _assignmentRepository = AssignmentRepository();
    _classRecordRepository = ClassRecordRepository(
      courseRepository: _courseRepository,
      quizRepository: _quizRepository,
      assignmentRepository: _assignmentRepository,
      attendanceRepository: _attendanceRepository,
    );
    _discussionRepository = DiscussionRepository();
    _notificationRepository = NotificationRepository();
    _fileRepository = FileRepository();
    _gradeRepository = GradeRepository(
      courseRepository: _courseRepository,
      quizRepository: _quizRepository,
      assignmentRepository: _assignmentRepository,
    );
    _settingsRepository = SettingsRepository();
    _supportRepository = SupportRepository();
    _authBloc = AuthBloc(authRepository: _authRepository);
    _appRouter = AppRouter(authBloc: _authBloc);
    _pushNotificationService = PushNotificationService(
      notificationRepository: _notificationRepository,
      firebaseAvailable: widget.firebaseMessagingAvailable,
      onOpenLocation: (location) => _appRouter.router.go(location),
    );
    _notificationRepository.configurePushLifecycle(
      requestPermission: _pushNotificationService.requestPermission,
      synchronize: _pushNotificationService.synchronize,
    );
    _pushAuthSubscription = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated && !state.isOffline) {
        unawaited(
          _pushNotificationService
              .activateUser(userId: state.user.id, role: state.user.role)
              .catchError((Object error, StackTrace stackTrace) {
                log('Push activation failed: $error', name: 'Main');
              }),
        );
      } else if (state is AuthUnauthenticated) {
        unawaited(
          _pushNotificationService.deactivateUser().catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            log('Push cleanup failed: $error', name: 'Main');
          }),
        );
      }
    });
    unawaited(_pushNotificationService.initialize());

    // Check authentication status on app start
    _authBloc.add(AuthCheckRequested());
  }

  @override
  void dispose() {
    _pushAuthSubscription?.cancel();
    unawaited(_pushNotificationService.dispose());
    _authBloc.close();
    _notificationRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<AttendanceRepository>.value(
          value: _attendanceRepository,
        ),
        RepositoryProvider<ClassRecordRepository>.value(
          value: _classRecordRepository,
        ),
        RepositoryProvider<CourseRepository>.value(value: _courseRepository),
        RepositoryProvider<CodeExecutionRepository>.value(
          value: _codeExecutionRepository,
        ),
        RepositoryProvider<LessonRepository>.value(value: _lessonRepository),
        RepositoryProvider<QuizRepository>.value(value: _quizRepository),
        RepositoryProvider<AssignmentRepository>.value(
          value: _assignmentRepository,
        ),
        RepositoryProvider<DiscussionRepository>.value(
          value: _discussionRepository,
        ),
        RepositoryProvider<NotificationRepository>.value(
          value: _notificationRepository,
        ),
        RepositoryProvider<FileRepository>.value(value: _fileRepository),
        RepositoryProvider<GradeRepository>.value(value: _gradeRepository),
        RepositoryProvider<SettingsRepository>.value(
          value: _settingsRepository,
        ),
        RepositoryProvider<SupportRepository>.value(
          value: _supportRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<CourseBloc>(
            create: (context) =>
                CourseBloc(courseRepository: _courseRepository),
          ),
          BlocProvider<GradesBloc>(
            create: (context) => GradesBloc(gradeRepository: _gradeRepository),
          ),
          BlocProvider<SettingsCubit>(
            create: (context) =>
                SettingsCubit(settingsRepository: _settingsRepository)
                  ..loadSettings(),
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (prev, curr) =>
              prev.settings.darkMode != curr.settings.darkMode,
          builder: (context, settingsState) {
            AppColors.isDarkMode = settingsState.settings.darkMode;
            return MaterialApp.router(
              title: 'BitClass',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settingsState.settings.darkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              routerConfig: _appRouter.router,
            );
          },
        ),
      ),
    );
  }
}
