/// Application-wide constants for BitClass LMS
library;

import 'package:package_info_plus/package_info_plus.dart';

/// App metadata
class AppConstants {
  AppConstants._();

  static const String appName = 'BitClass';
  static const String appTagline = 'Learn to Code, Code to Learn';

  /// Cached package info — call [initPackageInfo] before accessing
  static PackageInfo? _packageInfo;

  /// Initialize package info (call once at app startup)
  static Future<void> initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Full version string, e.g. '1.0.0+1'
  static String get appVersion {
    final info = _packageInfo;
    if (info == null) return 'Unknown';
    return '${info.version}+${info.buildNumber}';
  }

  /// Semantic version only, e.g. '1.0.0'
  static String get appVersionName => _packageInfo?.version ?? 'Unknown';

  /// Build number only, e.g. '1'
  static String get appBuildNumber => _packageInfo?.buildNumber ?? '';

  /// Supported programming languages for code editor
  static const List<String> supportedLanguages = [
    'python',
    'java',
    'c',
    'cpp',
    'javascript',
    'dart',
  ];

  /// Course categories
  static const List<String> courseCategories = [
    'Algorithms',
    'Data Structures',
    'Web Development',
    'Mobile Development',
    'AI/ML',
    'Databases',
    'Operating Systems',
    'Computer Networks',
    'Cybersecurity',
    'Other',
  ];

  /// Discussion channel types
  static const List<String> defaultChannels = [
    'announcements',
    'general',
    'help',
  ];

  /// Pagination
  static const int defaultPageSize = 20;

  /// Cache durations
  static const Duration lessonCacheDuration = Duration(days: 7);
  static const Duration courseCacheDuration = Duration(hours: 24);
}

/// Supabase table names
class SupabaseTables {
  SupabaseTables._();

  static const String users = 'users';
  static const String courses = 'courses';
  static const String enrollments = 'enrollments';
  static const String lessons = 'lessons';
  static const String modules = 'modules';
  static const String quizzes = 'quizzes';
  static const String questions = 'questions';
  static const String quizAttempts = 'quiz_attempts';
  static const String assignments = 'assignments';
  static const String submissions = 'submissions';
  static const String channels = 'channels';
  static const String threads = 'threads';
  static const String replies = 'replies';
  static const String notifications = 'notifications';
  static const String lessonProgress = 'lesson_progress';
}

/// Supabase Storage bucket paths
class SupabaseStoragePaths {
  SupabaseStoragePaths._();

  static const String avatars = 'avatars';
  static const String courseThumbnails = 'course_thumbnails';
  static const String materials = 'materials';
}
