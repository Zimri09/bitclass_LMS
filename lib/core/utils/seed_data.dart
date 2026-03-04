import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Utility class to seed sample data into Firestore
class SeedData {
  final FirebaseFirestore _firestore;

  SeedData({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Seed sample courses into Firestore
  Future<void> seedCourses() async {
    final coursesRef = _firestore.collection(FirestorePaths.courses);

    // Check if OUR seeded courses already exist by checking for specific ID
    final existing = await coursesRef.doc('course-1').get();
    if (existing.exists) {
      if (kDebugMode)
        log('Seed courses already exist. Skipping seed.', name: 'SeedData');
      return;
    }

    if (kDebugMode) log('Seeding sample courses...', name: 'SeedData');
    final now = DateTime.now();
    final courses = [
      {
        'title': 'Introduction to Flutter',
        'description':
            'Learn the fundamentals of Flutter development. Build beautiful, natively compiled applications from a single codebase. This comprehensive course covers widgets, state management, navigation, and more.',
        'category': 'Mobile Development',
        'instructorId': 'instructor-1',
        'instructorName': 'John Doe',
        'thumbnailUrl': null,
        'enrollmentCount': 156,
        'lessonCount': 12,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 30)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'title': 'Advanced Dart Programming',
        'description':
            'Master Dart programming language with advanced concepts like generics, async/await, streams, isolates, and more. Perfect for developers who want to level up their Dart skills.',
        'category': 'Programming',
        'instructorId': 'instructor-1',
        'instructorName': 'John Doe',
        'thumbnailUrl': null,
        'enrollmentCount': 89,
        'lessonCount': 15,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 25)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'title': 'Data Structures & Algorithms',
        'description':
            'A comprehensive guide to data structures and algorithms. Learn arrays, linked lists, trees, graphs, sorting, searching, and dynamic programming with practical examples.',
        'category': 'Algorithms',
        'instructorId': 'instructor-2',
        'instructorName': 'Jane Smith',
        'thumbnailUrl': null,
        'enrollmentCount': 234,
        'lessonCount': 20,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 60)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 10)).toIso8601String(),
      },
      {
        'title': 'Firebase for Flutter',
        'description':
            'Integrate Firebase services into your Flutter apps. Learn Authentication, Firestore, Cloud Storage, Cloud Functions, and Firebase Cloud Messaging.',
        'category': 'Backend',
        'instructorId': 'instructor-1',
        'instructorName': 'John Doe',
        'thumbnailUrl': null,
        'enrollmentCount': 67,
        'lessonCount': 8,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 15)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'title': 'Web Development with React',
        'description':
            'Build modern web applications with React. Learn components, hooks, state management with Redux, routing, and API integration. Includes project-based learning.',
        'category': 'Web Development',
        'instructorId': 'instructor-2',
        'instructorName': 'Jane Smith',
        'thumbnailUrl': null,
        'enrollmentCount': 312,
        'lessonCount': 18,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 45)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'title': 'Machine Learning Fundamentals',
        'description':
            'Introduction to machine learning concepts and algorithms. Learn supervised learning, unsupervised learning, neural networks, and practical ML applications.',
        'category': 'AI/ML',
        'instructorId': 'instructor-3',
        'instructorName': 'Dr. Alex Chen',
        'thumbnailUrl': null,
        'enrollmentCount': 198,
        'lessonCount': 16,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 40)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 7)).toIso8601String(),
      },
      {
        'title': 'SQL & Database Design',
        'description':
            'Master SQL queries and database design principles. Learn normalization, joins, indexes, stored procedures, and database optimization techniques.',
        'category': 'Databases',
        'instructorId': 'instructor-2',
        'instructorName': 'Jane Smith',
        'thumbnailUrl': null,
        'enrollmentCount': 145,
        'lessonCount': 14,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 55)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 12)).toIso8601String(),
      },
      {
        'title': 'Cybersecurity Essentials',
        'description':
            'Learn cybersecurity fundamentals including network security, cryptography, ethical hacking, and security best practices for developers.',
        'category': 'Cybersecurity',
        'instructorId': 'instructor-3',
        'instructorName': 'Dr. Alex Chen',
        'thumbnailUrl': null,
        'enrollmentCount': 87,
        'lessonCount': 10,
        'isPublished': true,
        'createdAt': now.subtract(const Duration(days: 20)).toIso8601String(),
        'updatedAt': now.subtract(const Duration(days: 4)).toIso8601String(),
      },
    ];

    // Add courses to Firestore
    for (int i = 0; i < courses.length; i++) {
      final courseId = 'course-${i + 1}';
      await coursesRef.doc(courseId).set(courses[i]);
      if (kDebugMode)
        log('Created course: ${courses[i]['title']}', name: 'SeedData');
    }

    if (kDebugMode)
      log('Successfully seeded ${courses.length} courses!', name: 'SeedData');
  }

  /// Seed sample lessons for a course
  Future<void> seedLessonsForCourse(String courseId) async {
    final lessonsRef = _firestore.collection(FirestorePaths.lessons);

    // Check if lessons already exist for this course
    final existing = await lessonsRef
        .where('courseId', isEqualTo: courseId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      if (kDebugMode)
        log('Lessons already exist for $courseId. Skipping.', name: 'SeedData');
      return;
    }

    final now = DateTime.now();
    final lessons = [
      {
        'courseId': courseId,
        'moduleId': 'module-1',
        'title': 'Getting Started',
        'description': 'Introduction and setup',
        'content':
            '# Getting Started\n\nWelcome to this course! In this lesson, we will set up our development environment.',
        'orderIndex': 0,
        'durationMinutes': 15,
        'type': 'video',
        'isPublished': true,
        'createdAt': now.toIso8601String(),
      },
      {
        'courseId': courseId,
        'moduleId': 'module-1',
        'title': 'Core Concepts',
        'description': 'Understanding the fundamentals',
        'content':
            '# Core Concepts\n\nIn this lesson, we cover the core concepts you need to know.',
        'orderIndex': 1,
        'durationMinutes': 25,
        'type': 'video',
        'isPublished': true,
        'createdAt': now.toIso8601String(),
      },
      {
        'courseId': courseId,
        'moduleId': 'module-1',
        'title': 'Hands-on Practice',
        'description': 'Apply what you learned',
        'content':
            '# Hands-on Practice\n\nNow let\'s put our knowledge into practice with exercises.',
        'orderIndex': 2,
        'durationMinutes': 30,
        'type': 'coding',
        'isPublished': true,
        'createdAt': now.toIso8601String(),
      },
    ];

    for (int i = 0; i < lessons.length; i++) {
      final lessonId = '$courseId-lesson-${i + 1}';
      await lessonsRef.doc(lessonId).set(lessons[i]);
    }

    if (kDebugMode)
      log('Created ${lessons.length} lessons for $courseId', name: 'SeedData');
  }

  /// Seed all sample data
  Future<void> seedAll() async {
    if (kDebugMode) log('Starting data seed...', name: 'SeedData');
    await seedCourses();

    // Seed lessons for the first course
    await seedLessonsForCourse('course-1');

    if (kDebugMode) log('Data seed complete!', name: 'SeedData');
  }

  /// Clear all seeded data (use with caution!)
  Future<void> clearAll() async {
    if (kDebugMode) log('Clearing all data...', name: 'SeedData');

    // Delete courses
    final courses = await _firestore.collection(FirestorePaths.courses).get();
    for (final doc in courses.docs) {
      await doc.reference.delete();
    }

    // Delete lessons
    final lessons = await _firestore.collection(FirestorePaths.lessons).get();
    for (final doc in lessons.docs) {
      await doc.reference.delete();
    }

    if (kDebugMode) log('All data cleared!', name: 'SeedData');
  }
}
