import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/bloc/app_bloc_observer.dart';
import 'core/constants/app_constants.dart';
import 'core/config/environment.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/utils/seed_data.dart';
import 'features/assignments/data/repositories/assignment_repository.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/courses/data/repositories/course_repository.dart';
import 'features/courses/presentation/bloc/course_bloc.dart';
import 'features/discussions/data/repositories/discussion_repository.dart';
import 'features/files/data/repositories/file_repository.dart';
import 'features/grades/data/repositories/grade_repository.dart';
import 'features/grades/presentation/bloc/grades_bloc.dart';
import 'features/lessons/data/repositories/lesson_repository.dart';
import 'features/notifications/data/repositories/notification_repository.dart';
import 'features/quizzes/data/repositories/quiz_repository.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

/// Whether the app is running in demo mode
/// Uses the centralized EnvironmentConfig
bool get kDemoMode => EnvironmentConfig.isDemoMode;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load package info (version, build number)
  await AppConstants.initPackageInfo();

  // Log environment on startup
  EnvironmentConfig.logEnvironment();

  // Initialize Supabase when that backend mode is enabled.
  if (EnvironmentConfig.useSupabase) {
    try {
      await Supabase.initialize(
        url: EnvironmentConfig.supabaseUrl,
        anonKey: EnvironmentConfig.supabaseAnonKey,
      );
      if (kDebugMode) {
        log('✓ Supabase initialized successfully', name: 'Main');
      }
    } catch (e) {
      if (kDebugMode) {
        log('✗ Supabase initialization failed: $e', name: 'Main');
      }
    }
  }

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Set up Bloc observer for debugging
  Bloc.observer = AppBlocObserver();

  runApp(const BitClassApp());
}

class BitClassApp extends StatefulWidget {
  const BitClassApp({super.key});

  @override
  State<BitClassApp> createState() => _BitClassAppState();
}

class _BitClassAppState extends State<BitClassApp> {
  late final AuthRepository _authRepository;
  late final CourseRepository _courseRepository;
  late final LessonRepository _lessonRepository;
  late final QuizRepository _quizRepository;
  late final AssignmentRepository _assignmentRepository;
  late final DiscussionRepository _discussionRepository;
  late final NotificationRepository _notificationRepository;
  late final FileRepository _fileRepository;
  late final GradeRepository _gradeRepository;
  late final SettingsRepository _settingsRepository;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _courseRepository = CourseRepository();
    _lessonRepository = LessonRepository();
    _quizRepository = QuizRepository();
    _assignmentRepository = AssignmentRepository();
    _discussionRepository = DiscussionRepository();
    _notificationRepository = NotificationRepository();
    _fileRepository = FileRepository();
    _gradeRepository = GradeRepository(
      courseRepository: _courseRepository,
      quizRepository: _quizRepository,
      assignmentRepository: _assignmentRepository,
    );
    _settingsRepository = SettingsRepository();
    _authBloc = AuthBloc(authRepository: _authRepository);
    _appRouter = AppRouter(authBloc: _authBloc);

    // Check authentication status on app start
    _authBloc.add(AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<CourseRepository>.value(value: _courseRepository),
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
