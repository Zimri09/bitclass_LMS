class AdminEnvironment {
  AdminEnvironment._();

  // Local development uses the same frontend-safe project values as the
  // learning app. Deployments can override both values with --dart-define.
  // Never put a service-role or secret key in this browser application.
  static const String _developmentSupabaseUrl =
      'https://ksrverpyybrwpoocbvqx.supabase.co';
  static const String _developmentSupabasePublishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcnZlcnB5eWJyd3Bvb2NidnF4Iiw'
      'icm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NzIxODUsImV4cCI6MjA5OTA0ODE4NX0.'
      'cJkIjJyDpm8pouZI83WCF-bDggKSAqGvnHAmht3wO5E';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _developmentSupabaseUrl,
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: _developmentSupabasePublishableKey,
  );

  static const String environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.hasScheme &&
        uri.host.endsWith('.supabase.co') &&
        supabasePublishableKey.isNotEmpty;
  }
}
