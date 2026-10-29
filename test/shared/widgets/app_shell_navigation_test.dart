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
  for (final width in [400.0, 800.0, 1200.0]) {
    testWidgets('active destination follows navigation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeAuthRepository();
      final notifications = _FakeNotificationRepository();
      final authBloc = AuthBloc(authRepository: repository)
        ..add(AuthUserUpdated(_studentUser));
      await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
      addTearDown(() async {
        await authBloc.close();
        await repository.dispose();
        await notifications.disposeFake();
      });

      final destinations = {
        'Classes': AppRoutes.dashboard,
        'To-do': AppRoutes.todos,
        'Code Lab': AppRoutes.codeLab,
        'Offline Files': AppRoutes.offlineFiles,
        'My Grades': AppRoutes.grades,
        'Notifications': AppRoutes.notifications,
        'Profile': AppRoutes.profile,
        'Settings': AppRoutes.settings,
      };
      final router = GoRouter(
        initialLocation: '${AppRoutes.profile}?tab=account',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              for (final entry in destinations.entries)
                GoRoute(
                  path: entry.value,
                  builder: (context, state) => _TestPage('${entry.key} page'),
                ),
              GoRoute(
                path: AppRoutes.notificationSettings,
                builder: (context, state) => const _TestPage('Alert settings'),
              ),
              GoRoute(
                path: AppRoutes.courses,
                builder: (context, state) => const _TestPage('Class catalog'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepositoryProvider<NotificationRepository>.value(
          value: notifications,
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openNavigation() async {
        if (width < 600) {
          await tester.tap(find.byTooltip('Open navigation').last);
          await tester.pumpAndSettle();
        }
      }

      void expectActive(String label) {
        for (final destination in destinations.keys) {
          final icon = tester.widget<Icon>(
            find.descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == destination,
              ),
              matching: find.byType(Icon),
            ),
          );
          expect(
            icon.color == AppColors.primary,
            destination == label,
            reason: '$destination when $label is open',
          );
        }
      }

      // A fresh router at a URL models a direct load or page refresh.
      await openNavigation();
      expectActive('Profile');
      for (final label in ['Classes', ...destinations.keys.skip(1)]) {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == label,
          ),
        );
        await tester.pumpAndSettle();
        await openNavigation();
        expectActive(label);
      }
      if (width < 600) {
        tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
        await tester.pumpAndSettle();
      }

      // Pop the pushed Settings page back to Profile.
      router.pop();
      await tester.pumpAndSettle();
      await openNavigation();
      expectActive('Profile');

      // URL-driven changes (including history restoration) and nested routes.
      for (final entry in {
        AppRoutes.notificationSettings: 'Notifications',
        AppRoutes.courses: 'Classes',
        AppRoutes.profile: 'Profile',
      }.entries) {
        router.go(entry.key);
        await tester.pumpAndSettle();
        expectActive(entry.value);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
