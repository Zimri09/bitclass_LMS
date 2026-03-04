/// Environment configuration for the BitClass app
///
/// This file controls whether the app runs in demo mode (with mock data)
/// or connects to real Firebase services.
library;

import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Environment type
enum Environment {
  /// Demo mode with mock data - no Firebase required
  demo,

  /// Development environment with real Firebase
  development,

  /// Production environment with real Firebase
  production,
}

/// Current environment configuration
class EnvironmentConfig {
  EnvironmentConfig._();

  /// Current environment - change this to switch modes
  static const Environment current = Environment.demo;

  /// Whether the app is running in demo mode
  static bool get isDemoMode => current == Environment.demo;

  /// Whether the app should use real Firebase services
  static bool get useFirebase => current != Environment.demo;

  /// Whether to show debug information
  static bool get showDebugInfo =>
      kDebugMode && current != Environment.production;

  /// Firebase project ID based on environment
  static String get firebaseProjectId {
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'bitclass-dev';
      case Environment.production:
        return 'bitclass-prod';
    }
  }

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

  /// Storage bucket URL
  static String get storageBucket {
    switch (current) {
      case Environment.demo:
        return '';
      case Environment.development:
        return 'gs://bitclass-dev.appspot.com';
      case Environment.production:
        return 'gs://bitclass-prod.appspot.com';
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
        'Firebase: ${useFirebase ? 'enabled' : 'disabled'}',
        name: 'Environment',
      );
      log('═══════════════════════════════════════════', name: 'Environment');
    }
  }
}
