import 'package:flutter/material.dart';

import '../../../core/auth/admin_session_controller.dart';
import '../../../core/theme/admin_theme.dart';

class AdminSessionErrorScreen extends StatelessWidget {
  final AdminSessionController session;

  const AdminSessionErrorScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 52,
                    color: AdminColors.danger,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Could not verify your session',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.message ?? 'Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: session.resolveSession,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                      OutlinedButton.icon(
                        onPressed: session.signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
