import 'dart:developer';
import 'dart:math' hide log;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/course_model.dart';

/// Repository handling course operations
class CourseRepository {
  static const String _coursesTable = 'courses';
  static const String _enrollmentsTable = 'enrollments';

  final SupabaseClient? _supabase;
  static const String _demoStudentUserId = 'demo-user-1';
  static final Random _random = Random();

  /// Generate a unique 6-character alphanumeric course code
  String _generateCourseCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    do {
      code = List.generate(
        6,
        (_) => chars[_random.nextInt(chars.length)],
      ).join();
    } while (_demoCourses.any((c) => c.courseCode == code));
    return code;
  }

  // Demo mode storage
  final List<CourseModel> _demoCourses = [];
  final List<EnrollmentModel> _demoEnrollments = [];

  CourseRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    // Initialize with demo data
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  void _initDemoData() {
    final now = DateTime.now();
    _demoCourses.addAll([
      CourseModel(
        id: 'course-1',
        title: 'Introduction to Flutter',
        description:
            'Learn the fundamentals of Flutter development. Build beautiful, natively compiled applications from a single codebase.',
        category: 'Mobile Development',
        instructorId: 'demo-instructor-1',
        instructorName: 'John Doe',
        thumbnailUrl: 'preset:blue-teal',
        enrollmentCount: 150,
        lessonCount: 8,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 30)),
        courseCode: 'FLT101',
      ),
      CourseModel(
        id: 'course-2',
        title: 'Advanced Dart Programming',
        description:
            'Master Dart programming language with advanced concepts like generics, async/await, streams, and more.',
        category: 'Programming',
        instructorId: 'demo-instructor-1',
        instructorName: 'John Doe',
        thumbnailUrl: 'preset:purple-pink',
        enrollmentCount: 89,
        lessonCount: 5,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
        courseCode: 'DAR202',
      ),
      CourseModel(
        id: 'course-3',
        title: 'Data Structures & Algorithms',
        description:
            'A comprehensive guide to data structures and algorithms using Dart. Perfect for coding interviews.',
        category: 'Computer Science',
        instructorId: 'demo-instructor-2',
        instructorName: 'Jane Smith',
        thumbnailUrl: 'preset:teal-green',
        enrollmentCount: 234,
        lessonCount: 4,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 60)),
        courseCode: 'DSA303',
      ),
    ]);

    // Seed demo enrollments so instructors can see enrolled students
    _demoEnrollments.addAll([
      // Pre-enroll the demo student user in courses 1, 2 & 3
      EnrollmentModel(
        id: 'enroll-demo-self-1',
        courseId: 'course-1',
        userId: 'demo-user-1',
        studentName: 'Demo Student',
        studentEmail: 'student@demo.com',
        progress: 0.35,
        completedLessons: 3,
        totalLessons: 8,
        enrolledAt: now.subtract(const Duration(days: 12)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-self-2',
        courseId: 'course-3',
        userId: 'demo-user-1',
        studentName: 'Demo Student',
        studentEmail: 'student@demo.com',
        progress: 0.25,
        completedLessons: 1,
        totalLessons: 4,
        enrolledAt: now.subtract(const Duration(days: 8)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-self-3',
        courseId: 'course-2',
        userId: 'demo-user-1',
        studentName: 'Demo Student',
        studentEmail: 'student@demo.com',
        progress: 0.4,
        completedLessons: 2,
        totalLessons: 5,
        enrolledAt: now.subtract(const Duration(days: 9)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-1',
        courseId: 'course-1',
        userId: 'student-1',
        studentName: 'Alice Johnson',
        studentEmail: 'alice.johnson@example.com',
        progress: 0.75,
        completedLessons: 9,
        totalLessons: 12,
        enrolledAt: now.subtract(const Duration(days: 20)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-2',
        courseId: 'course-1',
        userId: 'student-2',
        studentName: 'Bob Williams',
        studentEmail: 'bob.williams@example.com',
        progress: 0.42,
        completedLessons: 5,
        totalLessons: 12,
        enrolledAt: now.subtract(const Duration(days: 15)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-3',
        courseId: 'course-1',
        userId: 'student-3',
        studentName: 'Charlie Davis',
        studentEmail: 'charlie.d@example.com',
        progress: 1.0,
        completedLessons: 12,
        totalLessons: 12,
        enrolledAt: now.subtract(const Duration(days: 28)),
        completedAt: now.subtract(const Duration(days: 3)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-4',
        courseId: 'course-2',
        userId: 'student-1',
        studentName: 'Alice Johnson',
        studentEmail: 'alice.johnson@example.com',
        progress: 0.2,
        completedLessons: 3,
        totalLessons: 15,
        enrolledAt: now.subtract(const Duration(days: 5)),
      ),
      EnrollmentModel(
        id: 'enroll-demo-5',
        courseId: 'course-1',
        userId: 'student-4',
        studentName: 'Diana Martinez',
        studentEmail: 'diana.m@example.com',
        progress: 0.08,
        completedLessons: 1,
        totalLessons: 12,
        enrolledAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
  }

  CourseModel _courseFromRow(Map<String, dynamic> row, String id) {
    return CourseModel.fromMap({
      'title': row['title'],
      'description': row['description'],
      'category': row['category'],
      'instructorId': row['instructor_id'],
      'instructorName': row['instructor_name'],
      'instructorAvatarUrl': row['instructor_avatar_url'],
      'thumbnailUrl': row['thumbnail_url'],
      'enrollmentCount': row['enrollment_count'],
      'lessonCount': row['lesson_count'],
      'isPublished': row['is_published'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
      'courseCode': row['course_code'] as String? ?? '',
    }, id);
  }

  /// Validates a code and enrolls the authenticated student in one operation.
  Future<({CourseModel course, EnrollmentModel enrollment})> joinCourseByCode({
    required String code,
    required String userId,
    String? studentName,
    String? studentEmail,
  }) async {
    final upperCode = code.trim().toUpperCase();
    if (EnvironmentConfig.isDemoMode) {
      try {
        final course = _demoCourses.firstWhere(
          (c) =>
              c.courseCode.toUpperCase() == upperCode && c.isPublished,
        );
        if (_demoEnrollments.any(
          (e) => e.courseId == course.id && e.userId == userId,
        )) {
          throw Exception('You are already enrolled in this course.');
        }

        final enrollment = EnrollmentModel(
          id: 'enrollment-${DateTime.now().millisecondsSinceEpoch}',
          courseId: course.id,
          userId: userId,
          studentName: studentName,
          studentEmail: studentEmail,
          progress: 0.0,
          completedLessons: 0,
          totalLessons: course.lessonCount,
          enrolledAt: DateTime.now(),
        );
        _demoEnrollments.add(enrollment);

        final courseIndex = _demoCourses.indexWhere((c) => c.id == course.id);
        final current = _demoCourses[courseIndex];
        _demoCourses[courseIndex] = current.copyWith(
          enrollmentCount: current.enrollmentCount + 1,
          updatedAt: DateTime.now(),
        );
        return (course: _demoCourses[courseIndex], enrollment: enrollment);
      } on StateError {
        throw Exception('Invalid course code. Please check and try again.');
      }
    }

    final authenticatedUserId = _supabase!.auth.currentUser?.id;
    if (authenticatedUserId == null || authenticatedUserId != userId) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final response = await _supabase!.rpc(
      'join_course_by_code',
      params: {'join_code': upperCode},
    );
    final rows = (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rows.length != 1) {
      throw StateError('Could not join this course. Please try again.');
    }

    final courseId = rows.single['course_id'] as String;
    final course = await getCourse(courseId);
    final enrollment = await getEnrollment(courseId, authenticatedUserId);
    if (course == null || enrollment == null) {
      throw StateError('Could not load the course after joining.');
    }

    return (course: course, enrollment: enrollment);
  }

  EnrollmentModel _enrollmentFromRow(Map<String, dynamic> row, String id) {
    return EnrollmentModel.fromMap({
      'courseId': row['course_id'],
      'userId': row['user_id'],
      'studentName': row['student_name'],
      'studentEmail': row['student_email'],
      'progress': row['progress'],
      'completedLessons': row['completed_lessons'],
      'totalLessons': row['total_lessons'],
      'enrolledAt': row['enrolled_at']?.toString(),
      'completedAt': row['completed_at']?.toString(),
      'lastAccessedAt': row['last_accessed_at']?.toString(),
    }, id);
  }

  /// Get published courses the current student is already enrolled in.
  Future<List<CourseModel>> getCourses({
    String? category,
    String? searchQuery,
    int limit = 20,
    Object? startAfter,
  }) async {
    // Demo mode: return filtered demo courses
    if (EnvironmentConfig.isDemoMode) {
      final enrolledCourseIds = _demoEnrollments
          .where((e) => e.userId == _demoStudentUserId)
          .map((e) => e.courseId)
          .toSet();
      var courses = _demoCourses
          .where((c) => c.isPublished && enrolledCourseIds.contains(c.id))
          .toList();
      if (category != null && category.isNotEmpty) {
        courses = courses.where((c) => c.category == category).toList();
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        courses = courses
            .where(
              (c) =>
                  c.title.toLowerCase().contains(query) ||
                  c.description.toLowerCase().contains(query),
            )
            .toList();
      }
      courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit > 0 && courses.length > limit) {
        courses = courses.take(limit).toList();
      }
      return courses;
    }

    try {
      if (kDebugMode)
        log('Fetching courses from Supabase...', name: 'CourseRepository');

      final rows = await _supabase!
          .from(_coursesTable)
          .select()
          .eq('is_published', true);

      var courses = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => _courseFromRow(row, row['id'] as String))
          .toList();

      // Apply category filter
      if (category != null && category.isNotEmpty) {
        courses = courses.where((c) => c.category == category).toList();
      }

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        courses = courses
            .where(
              (c) =>
                  c.title.toLowerCase().contains(query) ||
                  c.description.toLowerCase().contains(query),
            )
            .toList();
      }

      courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply limit
      if (limit > 0 && courses.length > limit) {
        courses = courses.take(limit).toList();
      }

      return courses;
    } catch (e) {
      if (kDebugMode)
        log('Error fetching courses: $e', name: 'CourseRepository');
      return [];
    }
  }

  /// Get courses by instructor
  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoCourses.where((c) => c.instructorId == instructorId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    try {
      final rows = await _supabase!
          .from(_coursesTable)
          .select()
          .eq('instructor_id', instructorId);

      var courses = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => _courseFromRow(row, row['id'] as String))
          .toList();

      courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return courses;
    } catch (e) {
      if (kDebugMode)
        log('Error fetching instructor courses: $e', name: 'CourseRepository');
      return [];
    }
  }

  /// Get a single course by ID
  Future<CourseModel?> getCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoCourses.firstWhere((c) => c.id == courseId);
      } catch (_) {
        return null; // Course not found in demo data
      }
    }

    final row = await _supabase!
        .from(_coursesTable)
        .select()
        .eq('id', courseId)
        .maybeSingle();

    if (row == null) return null;
    return _courseFromRow(row, row['id'] as String);
  }

  /// Emits the current course record and later profile-synchronization updates.
  Stream<CourseModel?> watchCourse(String courseId) {
    if (EnvironmentConfig.isDemoMode) {
      final matchingCourses = _demoCourses
          .where((course) => course.id == courseId)
          .toList();
      return Stream.value(
        matchingCourses.isEmpty ? null : matchingCourses.first,
      );
    }

    return _supabase!
        .from(_coursesTable)
        .stream(primaryKey: ['id'])
        .eq('id', courseId)
        .map(
          (rows) => rows.isEmpty
              ? null
              : _courseFromRow(rows.first, rows.first['id'] as String),
        );
  }

  /// Create a new course
  Future<CourseModel> createCourse({
    required String title,
    required String description,
    required String category,
    required String instructorId,
    required String instructorName,
    String? thumbnailUrl,
    Uint8List? thumbnailBytes,
    String? thumbnailExtension,
    String? thumbnailMimeType,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final code = _generateCourseCode();
      final course = CourseModel(
        id: 'course-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        category: category,
        instructorId: instructorId,
        instructorName: instructorName,
        thumbnailUrl: thumbnailUrl,
        enrollmentCount: 0,
        lessonCount: 0,
        isPublished: false,
        createdAt: now,
        courseCode: code,
      );
      _demoCourses.add(course);
      return course;
    }

    // Generate a unique code for the Supabase-backed course
    String supabaseCode;
    while (true) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      supabaseCode = List.generate(
        6,
        (_) => chars[_random.nextInt(chars.length)],
      ).join();
      // Verify uniqueness in DB
      final existing = await _supabase!
          .from(_coursesTable)
          .select('id')
          .eq('course_code', supabaseCode)
          .maybeSingle();
      if (existing == null) break;
    }

    late final Map<String, dynamic> row;
    try {
      row = await _supabase!
          .from(_coursesTable)
          .insert({
            'title': title,
            'description': description,
            'category': category,
            'instructor_id': instructorId,
            'instructor_name': instructorName,
            'thumbnail_url': thumbnailUrl,
            'enrollment_count': 0,
            'lesson_count': 0,
            'is_published': false,
            'created_at': now.toIso8601String(),
            'course_code': supabaseCode,
          })
          .select()
          .single();
    } on PostgrestException catch (error, stackTrace) {
      if (kDebugMode) {
        log(
          'Course insert failed: ${error.message}',
          stackTrace: stackTrace,
        );
      }
      throw Exception('Course record creation failed: ${error.message}');
    }

    final course = _courseFromRow(row, row['id'] as String);
    if (thumbnailBytes == null) return course;

    try {
      final uploadedThumbnailUrl = await uploadCourseThumbnail(
        courseId: course.id,
        imageBytes: thumbnailBytes,
        extension: thumbnailExtension,
        mimeType: thumbnailMimeType,
      );
      return updateCourse(course.id, {'thumbnailUrl': uploadedThumbnailUrl});
    } catch (error, stackTrace) {
      // Keep course creation atomic from the instructor's perspective.
      try {
        await deleteCourse(course.id);
      } catch (cleanupError, cleanupStackTrace) {
        if (kDebugMode) {
          log(
            'Failed to remove course after banner upload failure: $cleanupError',
            stackTrace: cleanupStackTrace,
          );
        }
      }

      if (kDebugMode) {
        log(
          'Course banner upload failed for ${course.id}: $error',
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  /// Uploads a course banner and returns its public URL for `thumbnail_url`.
  Future<String> uploadCourseThumbnail({
    required String courseId,
    required Uint8List imageBytes,
    String? extension,
    String? mimeType,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      throw UnsupportedError('Course image uploads require development mode.');
    }

    final normalizedExtension = (extension ?? 'jpg')
        .replaceFirst(RegExp(r'^\\.'), '')
        .toLowerCase();
    final storagePath =
        '$courseId/thumbnails/${DateTime.now().microsecondsSinceEpoch}.$normalizedExtension';
    final bucket = EnvironmentConfig.storageBucket;

    await _supabase!.storage
        .from(bucket)
        .uploadBinary(
          storagePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );

    return _supabase!.storage.from(bucket).getPublicUrl(storagePath);
  }

  /// Update a course
  Future<CourseModel> updateCourse(
    String courseId,
    Map<String, dynamic> updates,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoCourses.indexWhere((c) => c.id == courseId);
      if (index == -1) {
        throw Exception('Course not found');
      }
      final current = _demoCourses[index];
      final updated = CourseModel(
        id: current.id,
        title: updates['title'] as String? ?? current.title,
        description: updates['description'] as String? ?? current.description,
        category: updates['category'] as String? ?? current.category,
        instructorId: current.instructorId,
        instructorName: current.instructorName,
        instructorAvatarUrl: current.instructorAvatarUrl,
        thumbnailUrl:
            updates['thumbnailUrl'] as String? ?? current.thumbnailUrl,
        enrollmentCount: current.enrollmentCount,
        lessonCount: current.lessonCount,
        isPublished: updates['isPublished'] as bool? ?? current.isPublished,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _demoCourses[index] = updated;
      return updated;
    }

    final dbUpdates = <String, dynamic>{};
    if (updates.containsKey('title')) dbUpdates['title'] = updates['title'];
    if (updates.containsKey('description')) {
      dbUpdates['description'] = updates['description'];
    }
    if (updates.containsKey('category'))
      dbUpdates['category'] = updates['category'];
    if (updates.containsKey('thumbnailUrl')) {
      dbUpdates['thumbnail_url'] = updates['thumbnailUrl'];
    }
    if (updates.containsKey('isPublished')) {
      dbUpdates['is_published'] = updates['isPublished'];
    }
    dbUpdates['updated_at'] = DateTime.now().toIso8601String();

    await _supabase!.from(_coursesTable).update(dbUpdates).eq('id', courseId);

    final updated = await getCourse(courseId);
    if (updated == null) {
      throw Exception('Failed to fetch updated course');
    }
    return updated;
  }

  /// Delete a course
  Future<void> deleteCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      _demoCourses.removeWhere((c) => c.id == courseId);
      _demoEnrollments.removeWhere((e) => e.courseId == courseId);
      return;
    }
    await _supabase!.from(_coursesTable).delete().eq('id', courseId);
  }

  /// Publish/unpublish a course
  Future<CourseModel> togglePublish(String courseId, bool publish) async {
    return updateCourse(courseId, {'isPublished': publish});
  }

  /// Get enrollment for a user in a course
  Future<EnrollmentModel?> getEnrollment(String courseId, String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoEnrollments.firstWhere(
          (e) => e.courseId == courseId && e.userId == userId,
        );
      } catch (_) {
        return null; // No enrollment found
      }
    }

    final row = await _supabase!
        .from(_enrollmentsTable)
        .select()
        .eq('course_id', courseId)
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return _enrollmentFromRow(row, row['id'] as String);
  }

  /// Get all enrollments for a user
  Future<List<EnrollmentModel>> getUserEnrollments(String userId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoEnrollments.where((e) => e.userId == userId).toList();
    }

    final rows = await _supabase!
        .from(_enrollmentsTable)
        .select()
        .eq('user_id', userId);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => _enrollmentFromRow(row, row['id'] as String))
        .toList();
  }

  /// Get all enrollments for a specific course (for instructors)
  Future<List<EnrollmentModel>> getCourseEnrollments(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoEnrollments.where((e) => e.courseId == courseId).toList()
        ..sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
    }

    try {
      final rows = await _supabase!
          .from(_enrollmentsTable)
          .select()
          .eq('course_id', courseId);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => _enrollmentFromRow(row, row['id'] as String))
          .toList()
        ..sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
    } catch (e) {
      if (kDebugMode)
        log('Error fetching enrollments: $e', name: 'CourseRepository');
      return [];
    }
  }

  /// Returns current public profile details for members of a course.
  /// The database function deliberately exposes no email or private profile data.
  Future<List<CourseRosterMember>> getCourseRoster(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoEnrollments
          .where((enrollment) => enrollment.courseId == courseId)
          .map(
            (enrollment) => CourseRosterMember(
              userId: enrollment.userId,
              displayName: enrollment.studentName ?? 'Student',
            ),
          )
          .toList();
    }

    final rows = await _supabase!.rpc(
      'get_course_roster',
      params: {'target_course_id': courseId},
    );
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CourseRosterMember.fromMap)
        .toList();
  }

  /// Update enrollment progress
  Future<void> updateEnrollmentProgress({
    required String courseId,
    required String enrollmentId,
    required double progress,
    required int completedLessons,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoEnrollments.indexWhere((e) => e.id == enrollmentId);
      if (index != -1) {
        final current = _demoEnrollments[index];
        _demoEnrollments[index] = EnrollmentModel(
          id: current.id,
          courseId: current.courseId,
          userId: current.userId,
          progress: progress,
          completedLessons: completedLessons,
          totalLessons: current.totalLessons,
          enrolledAt: current.enrolledAt,
          lastAccessedAt: DateTime.now(),
          completedAt: progress >= 1.0 ? DateTime.now() : current.completedAt,
        );
      }
      return;
    }

    final updates = <String, dynamic>{
      'progress': progress,
      'completed_lessons': completedLessons,
      'last_accessed_at': DateTime.now().toIso8601String(),
    };

    if (progress >= 1.0) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await _supabase!
        .from(_enrollmentsTable)
        .update(updates)
        .eq('id', enrollmentId)
        .eq('course_id', courseId);
  }

  /// Unenroll from a course
  Future<void> unenrollFromCourse(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      _demoEnrollments.removeWhere(
        (enrollment) =>
            enrollment.courseId == courseId &&
            enrollment.userId == _demoStudentUserId,
      );
      final courseIndex = _demoCourses.indexWhere((c) => c.id == courseId);
      if (courseIndex != -1) {
        final current = _demoCourses[courseIndex];
        _demoCourses[courseIndex] = CourseModel(
          id: current.id,
          title: current.title,
          description: current.description,
          category: current.category,
          instructorId: current.instructorId,
          instructorName: current.instructorName,
          instructorAvatarUrl: current.instructorAvatarUrl,
          thumbnailUrl: current.thumbnailUrl,
          enrollmentCount: (current.enrollmentCount - 1).clamp(0, 99999),
          lessonCount: current.lessonCount,
          isPublished: current.isPublished,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        );
      }
      return;
    }

    await _supabase!.rpc(
      'unenroll_from_course',
      params: {'target_course_id': courseId},
    );
  }
}
