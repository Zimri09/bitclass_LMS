/// Environment configuration for the BitClass app
///
/// This file controls whether the app runs in demo mode (with mock data)
/// or connects to real Supabase services.
library;

import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Environment type
enum Environment {
  /// Demo mode with mock data - no backend required
  demo,

  /// Development environment with real Supabase
  development,

  /// Production environment with real Supabase
  production,
}

/// Current environment configuration
class EnvironmentConfig {
  EnvironmentConfig._();

  static const String _environmentName = String.fromEnvironment(
    'BITCLASS_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );
  static const String _definedSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _definedSupabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String _definedCourseMaterialsBucket = String.fromEnvironment(
    'COURSE_MATERIALS_BUCKET',
  );
  static const String _definedCourseThumbnailsBucket = String.fromEnvironment(
    'COURSE_THUMBNAILS_BUCKET',
  );

  /// Build environment selected with `--dart-define=BITCLASS_ENV=...`.
  static Environment get current => switch (_environmentName.toLowerCase()) {
    'demo' => Environment.demo,
    'development' => Environment.development,
    'production' => Environment.production,
    _ => throw StateError('Unsupported BITCLASS_ENV: $_environmentName'),
  };

  /// Backend provider for real services.
  ///
  /// Demo mode bypasses Supabase entirely.
  static const String backendProvider = 'supabase';

  /// Whether the app is running in demo mode
  static bool get isDemoMode => current == Environment.demo;

  /// Whether the app should use Supabase services.
  static bool get useSupabase =>
      current != Environment.demo && backendProvider == 'supabase';

  /// Whether to show debug information
  static bool get showDebugInfo =>
      kDebugMode && current != Environment.production;

  /// API base URL for any external services
  static String get apiBaseUrl {
    switch (current) {
      case Environment.demo:
        return 'https://demo.bitclass.app';
      case Environment.development:
        return 'https://dev-api.bitclass.app';
      case Environment.production:
        return 'https://api.bitclass.app';
    }
  }

  /// Supabase project URL.
  static String get supabaseUrl {
    if (_definedSupabaseUrl.isNotEmpty) return _definedSupabaseUrl;
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'https://ksrverpyybrwpoocbvqx.supabase.co';
      case Environment.production:
        return '';
    }
  }

  /// Supabase client-side publishable key (legacy anon JWTs are supported).
  static String get supabasePublishableKey {
    if (_definedSupabaseKey.isNotEmpty) return _definedSupabaseKey;
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcnZlcnB5eWJyd3Bvb2NidnF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NzIxODUsImV4cCI6MjA5OTA0ODE4NX0.cJkIjJyDpm8pouZI83WCF-bDggKSAqGvnHAmht3wO5E';
      case Environment.production:
        return '';
    }
  }

  @Deprecated('Use supabasePublishableKey instead.')
  static String get supabaseAnonKey => supabasePublishableKey;

  /// Supabase Storage bucket name.
  static String get storageBucket {
    if (_definedCourseThumbnailsBucket.isNotEmpty) {
      return _definedCourseThumbnailsBucket;
    }
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        // This must match the bucket created by supabase/setup_storage.sql.
        return 'bitclass_storage';
      case Environment.production:
        return 'bitclass_storage';
    }
  }

  /// Private bucket used for course and lesson learning materials.
  static String get courseMaterialsBucket {
    if (_definedCourseMaterialsBucket.isNotEmpty) {
      return _definedCourseMaterialsBucket;
    }
    return isDemoMode ? '' : 'course_materials';
  }

  /// Stops a release build from silently using development or placeholder data.
  static void validate() {
    if (kReleaseMode && current != Environment.production) {
      throw StateError('Release builds require BITCLASS_ENV=production.');
    }
    if (!useSupabase) return;

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('A valid HTTPS SUPABASE_URL is required.');
    }
    final key = supabasePublishableKey;
    if (key.startsWith('YOUR_') ||
        (!key.startsWith('sb_publishable_') && !key.startsWith('eyJ'))) {
      throw StateError('SUPABASE_PUBLISHABLE_KEY is required.');
    }
    if (storageBucket.isEmpty || courseMaterialsBucket.isEmpty) {
      throw StateError('Supabase Storage bucket names are required.');
    }
  }

  /// Log current environment on startup
  static void logEnvironment() {
    if (kDebugMode) {
      log('----------------------------------------', name: 'Environment');
      log(
        'BitClass Environment: ${current.name.toUpperCase()}',
        name: 'Environment',
      );
      log('Demo Mode: $isDemoMode', name: 'Environment');
      log(
        'Backend: ${useSupabase ? 'Supabase' : 'none (demo)'}',
        name: 'Environment',
      );
      log('----------------------------------------', name: 'Environment');
    }
  }
}
