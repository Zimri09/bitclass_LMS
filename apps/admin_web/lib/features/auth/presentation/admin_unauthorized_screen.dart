import 'package:flutter/material.dart';

import '../../../core/auth/admin_session_controller.dart';
import '../../../core/theme/admin_theme.dart';

class AdminUnauthorizedScreen extends StatelessWidget {
  final AdminSessionController session;

  const AdminUnauthorizedScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final account = session.account;
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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AdminColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_outlined,
                      size: 34,
                      color: AdminColors.warning,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Administrator access required',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.message ?? 'This account is not authorized for the admin dashboard.',
                    textAlign: TextAlign.center,
                  ),
                  if (account != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${account.email} • ${account.role}',
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  ElevatedButton.icon(
                    onPressed: session.isSubmitting ? null : session.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
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
