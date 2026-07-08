import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Utility class reserved for development data seeding.
///
/// Supabase seeding is handled by SQL migrations and seed scripts.
class SeedData {
  SeedData();

  /// Seed sample courses.
  ///
  /// Supabase-backed development data should be inserted through SQL.
  Future<void> seedCourses() async {
    if (kDebugMode) {
      log(
        'Supabase seed data is handled by SQL migrations, not the app runtime.',
        name: 'SeedData',
      );
    }
  }

  /// Seed sample lessons for a course.
  Future<void> seedLessonsForCourse(String courseId) async {
    if (kDebugMode) {
      log(
        'Skipping runtime lesson seed for $courseId; use SQL seed scripts.',
        name: 'SeedData',
      );
    }
  }

  /// Seed all sample data
  Future<void> seedAll() async {
    if (kDebugMode) {
      log('Supabase seed is handled by SQL migrations.', name: 'SeedData');
    }
  }

  /// Clear all seeded data (use with caution!)
  Future<void> clearAll() async {
    if (kDebugMode) {
      log('No runtime seed data to clear for Supabase.', name: 'SeedData');
    }
  }
}
