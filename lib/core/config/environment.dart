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

  /// Current environment - change this to switch modes
  static const Environment current = Environment.development;

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
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'https://ksrverpyybrwpoocbvqx.supabase.co';
      case Environment.production:
        return 'https://YOUR-PROJECT.supabase.co';
    }
  }

  /// Supabase public anon key.
  static String get supabaseAnonKey {
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'sb_publishable_mBj1Da-qQw21P1ifD5PULQ_bJvyXqje';
      case Environment.production:
        return 'YOUR_SUPABASE_ANON_KEY';
    }
  }

  /// Supabase Storage bucket name.
  static String get storageBucket {
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'bitclass-dev';
      case Environment.production:
        return 'bitclass-prod';
    }
  }

  /// Log current environment on startup
  static void logEnvironment() {
    if (kDebugMode) {
      log('═══════════════════════════════════════════', name: 'Environment');
      log(
        'BitClass Environment: ${current.name.toUpperCase()}',
        name: 'Environment',
      );
      log('Demo Mode: $isDemoMode', name: 'Environment');
      log(
        'Backend: ${useSupabase ? 'Supabase' : 'none (demo)'}',
        name: 'Environment',
      );
      log('═══════════════════════════════════════════', name: 'Environment');
    }
  }
}
