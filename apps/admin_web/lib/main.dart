import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/admin_auth_service.dart';
import 'core/auth/admin_session_controller.dart';
import 'core/config/admin_environment.dart';
import 'features/dashboard/data/supabase_admin_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AdminEnvironment.isConfigured) {
    runApp(const AdminConfigurationApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: AdminEnvironment.supabaseUrl,
      publishableKey: AdminEnvironment.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    final client = Supabase.instance.client;
    final repository = SupabaseAdminRepository(client);
    final session = AdminSessionController(
      SupabaseAdminAuthService(client),
      repository,
    );
    await session.initialize();

    runApp(AdminApp(session: session, repository: repository));
  } catch (error) {
    runApp(AdminConfigurationApp(initializationError: error.toString()));
  }
}
