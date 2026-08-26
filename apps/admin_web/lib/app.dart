import 'package:flutter/material.dart';

import 'core/auth/admin_session_controller.dart';
import 'core/router/admin_router.dart';
import 'core/theme/admin_theme.dart';
import 'features/dashboard/data/admin_repository.dart';

class AdminApp extends StatefulWidget {
  final AdminSessionController session;
  final AdminRepository repository;

  const AdminApp({super.key, required this.session, required this.repository});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final _router = createAdminRouter(widget.session, widget.repository);

  @override
  void dispose() {
    _router.dispose();
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BitClass Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark,
      darkTheme: AdminTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}

class AdminConfigurationApp extends StatelessWidget {
  final String? initializationError;

  const AdminConfigurationApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitClass Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 52,
                      color: AdminColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Admin configuration required',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: AdminColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Verify the Supabase URL and frontend-safe publishable '
                      'key. Custom environments can supply both values '
                      'through dart-define.',
                      textAlign: TextAlign.center,
                    ),
                    if (initializationError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        initializationError!,
                        style: const TextStyle(color: AdminColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
