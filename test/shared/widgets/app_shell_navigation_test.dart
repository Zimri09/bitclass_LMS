import 'dart:async';

import 'package:bitclass/core/router/app_routes.dart';
import 'package:bitclass/core/theme/app_colors.dart';
import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/notifications/data/models/notification_model.dart';
import 'package:bitclass/features/notifications/data/repositories/notification_repository.dart';
import 'package:bitclass/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('admin receives instructor navigation', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeAuthRepository();
    final notificationRepository = _FakeNotificationRepository();
    final authBloc = AuthBloc(authRepository: repository)
      ..add(AuthUserUpdated(_adminUser));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    addTearDown(() async {
      await authBloc.close();
      await repository.dispose();
      await notificationRepository.disposeFake();
    });

    final router = GoRouter(
      initialLocation: AppRoutes.dashboard,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (context, state) => const _TestPage('Class list'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepositoryProvider<NotificationRepository>.value(
        value: notificationRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Work Queue'), findsOneWidget);
    expect(find.text('Create Course'), findsOneWidget);
    expect(find.text('Support Inbox'), findsOneWidget);
    expect(find.text('To-do'), findsNothing);
    expect(find.text('My Grades'), findsNothing);
  });

  testWidgets('Classes returns to the class list and becomes selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeAuthRepository();
    final notificationRepository = _FakeNotificationRepository();
    final authBloc = AuthBloc(authRepository: repository)
      ..add(AuthUserUpdated(_testUser));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    addTearDown(() async {
      await authBloc.close();
      await repository.dispose();
      await notificationRepository.disposeFake();
    });

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (context, state) => const _TestPage('Class list'),
            ),
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const _TestPage('Profile page'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepositoryProvider<NotificationRepository>.value(
        value: notificationRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Support Inbox'), findsNothing);
    expect(
      find.ancestor(of: find.text('ACCOUNT'), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);

    await tester.tap(find.text('Classes'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.dashboard);
    expect(find.text('Class list'), findsWidgets);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.dashboard), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Classes')).style?.color,
      AppColors.primary,
    );
  });

  testWidgets('unread activity shows dots on related student destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeAuthRepository();
    final notificationRepository = _FakeNotificationRepository({
      NotificationType.newAssignment,
      NotificationType.assignmentGraded,
      NotificationType.discussionReply,
    });
    final authBloc = AuthBloc(authRepository: repository)
      ..add(AuthUserUpdated(_studentUser));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    addTearDown(() async {
      await authBloc.close();
      await repository.dispose();
      await notificationRepository.disposeFake();
    });

    final router = GoRouter(
      initialLocation: AppRoutes.dashboard,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (context, state) => const _TestPage('Class list'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepositoryProvider<NotificationRepository>.value(
        value: notificationRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('nav-unread-dot-${AppRoutes.todos}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('nav-unread-dot-${AppRoutes.grades}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('nav-unread-dot-${AppRoutes.notifications}')),
      findsOneWidget,
    );
  });
}

class _TestPage extends StatelessWidget {
  final String title;

  const _TestPage(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppDrawerButton(), title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

final _testUser = UserModel(
  id: 'instructor-1',
  email: 'instructor@example.com',
  firstName: 'Test',
  lastName: 'Instructor',
  role: 'instructor',
  createdAt: DateTime.utc(2026, 8, 2),
);

final _adminUser = UserModel(
  id: 'admin-1',
  email: 'admin@example.com',
  firstName: 'Test',
  lastName: 'Admin',
  role: 'admin',
  createdAt: DateTime.utc(2026, 8, 18),
);

final _studentUser = UserModel(
  id: 'student-1',
  email: 'student@example.com',
  firstName: 'Test',
  lastName: 'Student',
  role: 'student',
  createdAt: DateTime.utc(2026, 8, 26),
);

class _FakeAuthRepository extends AuthRepository {
  final SupabaseClient _client;
  final _authController = StreamController<User?>.broadcast();

  factory _FakeAuthRepository() {
    return _FakeAuthRepository._(
      SupabaseClient('http://localhost:54321', 'test-anon-key'),
    );
  }

  _FakeAuthRepository._(this._client) : super(supabase: _client) {
    _client.auth.stopAutoRefresh();
  }

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  Future<void> dispose() async {
    _client.auth.dispose();
    await _authController.close();
  }
}

class _FakeNotificationRepository extends NotificationRepository {
  final SupabaseClient _client;
  final Set<NotificationType> unreadTypes;

  factory _FakeNotificationRepository([
    Set<NotificationType> unreadTypes = const {},
  ]) {
    return _FakeNotificationRepository._(
      SupabaseClient('http://localhost:54321', 'test-anon-key'),
      unreadTypes,
    );
  }

  _FakeNotificationRepository._(this._client, this.unreadTypes)
    : super(supabase: _client) {
    _client.auth.stopAutoRefresh();
  }

  @override
  Future<Set<NotificationType>> getUnreadTypes(String userId) async =>
      unreadTypes;

  Future<void> disposeFake() async {
    dispose();
    _client.auth.dispose();
  }
}
