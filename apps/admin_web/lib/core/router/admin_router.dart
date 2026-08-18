import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/admin_login_screen.dart';
import '../../features/auth/presentation/admin_session_error_screen.dart';
import '../../features/auth/presentation/admin_unauthorized_screen.dart';
import '../../features/audit/presentation/admin_audit_screen.dart';
import '../../features/courses/presentation/admin_courses_screen.dart';
import '../../features/dashboard/data/admin_repository.dart';
import '../../features/dashboard/presentation/admin_overview_screen.dart';
import '../../features/users/presentation/admin_users_screen.dart';
import '../auth/admin_session_controller.dart';
import '../widgets/admin_shell.dart';

GoRouter createAdminRouter(
  AdminSessionController session,
  AdminRepository repository,
) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      switch (session.status) {
        case AdminSessionStatus.checking:
          return path == '/' ? null : '/';
        case AdminSessionStatus.signedOut:
          return path == '/login' ? null : '/login';
        case AdminSessionStatus.forbidden:
          return path == '/unauthorized' ? null : '/unauthorized';
        case AdminSessionStatus.failure:
          return path == '/session-error' ? null : '/session-error';
        case AdminSessionStatus.authorized:
          if (path == '/' ||
              path == '/login' ||
              path == '/unauthorized' ||
              path == '/session-error') {
            return '/overview';
          }
          return null;
      }
    },
    errorBuilder: (context, state) => const _AdminNotFoundScreen(),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _AdminLoadingScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => AdminLoginScreen(session: session),
      ),
      GoRoute(
        path: '/unauthorized',
        builder: (_, _) => AdminUnauthorizedScreen(session: session),
      ),
      GoRoute(
        path: '/session-error',
        builder: (_, _) => AdminSessionErrorScreen(session: session),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(
          session: session,
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/overview',
            builder: (_, _) => AdminOverviewScreen(repository: repository),
          ),
          GoRoute(
            path: '/users',
            builder: (_, _) => AdminUsersScreen(repository: repository),
          ),
          GoRoute(
            path: '/courses',
            builder: (_, _) => AdminCoursesScreen(repository: repository),
          ),
          GoRoute(
            path: '/audit',
            builder: (_, _) => AdminAuditScreen(repository: repository),
          ),
        ],
      ),
    ],
  );
}

class _AdminLoadingScreen extends StatelessWidget {
  const _AdminLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AdminNotFoundScreen extends StatelessWidget {
  const _AdminNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/overview'),
              child: const Text('Return to overview'),
            ),
          ],
        ),
      ),
    );
  }
}
