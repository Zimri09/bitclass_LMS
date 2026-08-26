import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

part '../fixtures/lesson_demo_content.dart';

/// Repository handling lesson and module operations
class LessonRepository {
  static const String _modulesTable = 'modules';
  static const String _lessonsTable = 'lessons';
  static const String _lessonProgressTable = 'lesson_progress';
  static const String _filesTable = 'files';

  final SupabaseClient? _supabase;

  // Demo mode storage
  final List<ModuleModel> _demoModules = [];
  final List<LessonModel> _demoLessons = [];
  final List<LessonProgressModel> _demoProgress = [];

  LessonRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  ModuleModel _moduleFromRow(Map<String, dynamic> row, String id) {
    return ModuleModel.fromMap({
      'courseId': row['course_id'],
      'title': row['title'],
      'description': row['description'],
      'order': row['sort_order'],
      'isPublished': row['is_published'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    }, id);
  }

  LessonModel _lessonFromRow(Map<String, dynamic> row, String id) {
    return LessonModel.fromMap({
      'courseId': row['course_id'],
      'moduleId': row['module_id'],
      'title': row['title'],
      'description': row['description'],
      'order': row['sort_order'],
      'type': row['lesson_type'],
      'content': row['content'],
      'videoUrl': row['video_url'],
      'durationMinutes': row['duration_minutes'],
      'isPublished': row['is_published'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    }, id);
  }

  LessonProgressModel _progressFromRow(Map<String, dynamic> row, String id) {
    return LessonProgressModel.fromMap({
      'lessonId': row['lesson_id'],
      'enrollmentId': row['enrollment_id'],
      'userId': row['user_id'],
      'isCompleted': row['is_completed'],
      'completedAt': row['completed_at']?.toString(),
      'lastAccessedAt': row['last_accessed_at']?.toString(),
      'savedState': row['saved_state'],
    }, id);
  }

  void _initDemoData() {
    final now = DateTime.now();

    // Course 1: Introduction to Flutter - Modules
    _demoModules.addAll([
      ModuleModel(
        id: 'module-1-1',
        courseId: 'course-1',
        title: 'Getting Started',
        description: 'Set up your Flutter development environment',
        order: 0,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      ModuleModel(
        id: 'module-1-2',
        courseId: 'course-1',
        title: 'Dart Fundamentals',
        description: 'Learn the basics of Dart programming language',
        order: 1,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      ModuleModel(
        id: 'module-1-3',
        courseId: 'course-1',
        title: 'Building Your First App',
        description: 'Create a complete Flutter application from scratch',
        order: 2,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 26)),
      ),
    ]);

    // Course 1 Lessons
    _demoLessons.addAll([
      LessonModel(
        id: 'lesson-1-1-1',
        courseId: 'course-1',
        moduleId: 'module-1-1',
        title: 'Installing Flutter SDK',
        description: 'Download and configure Flutter on your machine',
        order: 0,
        type: LessonType.text,
        content: _getFlutterInstallContent(),
        durationMinutes: 15,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      LessonModel(
        id: 'lesson-1-1-2',
        courseId: 'course-1',
        moduleId: 'module-1-1',
        title: 'IDE Setup',
        description: 'Configure VS Code or Android Studio for Flutter',
        order: 1,
        type: LessonType.text,
        content: _getIDESetupContent(),
        durationMinutes: 10,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 29)),
      ),
      LessonModel(
        id: 'lesson-1-2-1',
        courseId: 'course-1',
        moduleId: 'module-1-2',
        title: 'Variables and Types',
        description: 'Understanding Dart type system',
        order: 0,
        type: LessonType.code,
        content: _getDartVariablesContent(),
        durationMinutes: 20,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      LessonModel(
        id: 'lesson-1-2-2',
        courseId: 'course-1',
        moduleId: 'module-1-2',
        title: 'Functions and Classes',
        description: 'Object-oriented programming in Dart',
        order: 1,
        type: LessonType.code,
        content: _getDartFunctionsContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 27)),
      ),
      LessonModel(
        id: 'lesson-1-3-1',
        courseId: 'course-1',
        moduleId: 'module-1-3',
        title: 'Widget Basics',
        description: 'Learn about StatelessWidget and StatefulWidget',
        order: 0,
        type: LessonType.code,
        content: _getWidgetBasicsContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 26)),
      ),
      LessonModel(
        id: 'lesson-1-3-2',
        courseId: 'course-1',
        moduleId: 'module-1-3',
        title: 'Layouts: Row, Column & Stack',
        description: 'Master Flutter layout widgets',
        order: 1,
        type: LessonType.code,
        content: _getLayoutsContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      LessonModel(
        id: 'lesson-1-3-3',
        courseId: 'course-1',
        moduleId: 'module-1-3',
        title: 'Navigation & Routing',
        description: 'Navigate between screens using Navigator and GoRouter',
        order: 2,
        type: LessonType.code,
        content: _getNavigationContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
    ]);

    // Course 2: Advanced Dart - Modules
    _demoModules.addAll([
      ModuleModel(
        id: 'module-2-1',
        courseId: 'course-2',
        title: 'Asynchronous Programming',
        description: 'Master async/await, Futures, and Streams',
        order: 0,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      ModuleModel(
        id: 'module-2-2',
        courseId: 'course-2',
        title: 'Generics & Collections',
        description: 'Type-safe data structures in Dart',
        order: 1,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
    ]);

    // Course 2 Lessons
    _demoLessons.addAll([
      LessonModel(
        id: 'lesson-2-1-1',
        courseId: 'course-2',
        moduleId: 'module-2-1',
        title: 'Understanding Futures',
        description: 'How asynchronous operations work in Dart',
        order: 0,
        type: LessonType.code,
        content: _getFuturesContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      LessonModel(
        id: 'lesson-2-1-2',
        courseId: 'course-2',
        moduleId: 'module-2-1',
        title: 'Working with Streams',
        description: 'Handle continuous data flows',
        order: 1,
        type: LessonType.code,
        content: _getStreamsContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
      LessonModel(
        id: 'lesson-2-2-1',
        courseId: 'course-2',
        moduleId: 'module-2-2',
        title: 'Generic Types',
        description: 'Write reusable, type-safe code',
        order: 0,
        type: LessonType.code,
        content: _getGenericsContent(),
        durationMinutes: 20,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 23)),
      ),
      LessonModel(
        id: 'lesson-2-2-2',
        courseId: 'course-2',
        moduleId: 'module-2-2',
        title: 'Collections & Iterables',
        description: 'Master List, Set, Map and iterable methods',
        order: 1,
        type: LessonType.code,
        content: _getCollectionsContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 22)),
      ),
      LessonModel(
        id: 'lesson-2-1-3',
        courseId: 'course-2',
        moduleId: 'module-2-1',
        title: 'Error Handling & Isolates',
        description: 'Manage exceptions and parallel execution',
        order: 2,
        type: LessonType.code,
        content: _getErrorHandlingContent(),
        durationMinutes: 20,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 21)),
      ),
    ]);

    // Course 3: Data Structures - Modules
    _demoModules.addAll([
      ModuleModel(
        id: 'module-3-1',
        courseId: 'course-3',
        title: 'Arrays and Lists',
        description: 'Fundamental data structures',
        order: 0,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      ModuleModel(
        id: 'module-3-2',
        courseId: 'course-3',
        title: 'Trees and Graphs',
        description: 'Hierarchical and networked data',
        order: 1,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 55)),
      ),
    ]);

    // Course 3 Lessons
    _demoLessons.addAll([
      LessonModel(
        id: 'lesson-3-1-1',
        courseId: 'course-3',
        moduleId: 'module-3-1',
        title: 'Array Operations',
        description: 'Common array algorithms and complexity',
        order: 0,
        type: LessonType.code,
        content: _getArraysContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      LessonModel(
        id: 'lesson-3-2-1',
        courseId: 'course-3',
        moduleId: 'module-3-2',
        title: 'Binary Trees',
        description: 'Tree traversal algorithms',
        order: 0,
        type: LessonType.code,
        content: _getBinaryTreesContent(),
        durationMinutes: 35,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 55)),
      ),
      LessonModel(
        id: 'lesson-3-1-2',
        courseId: 'course-3',
        moduleId: 'module-3-1',
        title: 'Linked Lists',
        description: 'Singly and doubly linked list implementations',
        order: 1,
        type: LessonType.code,
        content: _getLinkedListContent(),
        durationMinutes: 30,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 54)),
      ),
      LessonModel(
        id: 'lesson-3-2-2',
        courseId: 'course-3',
        moduleId: 'module-3-2',
        title: 'Hash Maps & Sets',
        description: 'Hashing, collision resolution, and Dart implementations',
        order: 1,
        type: LessonType.code,
        content: _getHashMapContent(),
        durationMinutes: 25,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 53)),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo Content Generators
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // Module Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all modules for a course
  Future<List<ModuleModel>> getModules(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      final modules = _demoModules
          .where((m) => m.courseId == courseId)
          .toList();
      modules.sort((a, b) => a.order.compareTo(b.order));
      return modules;
    }

    final rows = await _supabase!
        .from(_modulesTable)
        .select()
        .eq('course_id', courseId)
        .order('sort_order');

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => _moduleFromRow(row, row['id'] as String))
        .toList();
  }

  /// Get a single module
  Future<ModuleModel?> getModule(String courseId, String moduleId) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoModules.firstWhere((m) => m.id == moduleId);
      } catch (_) {
        return null; // Module not found in demo data
      }
    }

    final row = await _supabase!
        .from(_modulesTable)
        .select()
        .eq('course_id', courseId)
        .eq('id', moduleId)
        .maybeSingle();

    if (row == null) return null;
    return _moduleFromRow(row, row['id'] as String);
  }

  /// Create a new module
  Future<ModuleModel> createModule({
    required String courseId,
    required String title,
    String? description,
    required int order,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final module = ModuleModel(
        id: 'module-${DateTime.now().millisecondsSinceEpoch}',
        courseId: courseId,
        title: title,
        description: description,
        order: order,
        isPublished: false,
        createdAt: now,
      );
      _demoModules.add(module);
      return module;
    }

    final row = await _supabase!
        .from(_modulesTable)
        .insert({
          'course_id': courseId,
          'title': title,
          'description': description,
          'sort_order': order,
          'is_published': false,
          'created_at': now.toIso8601String(),
        })
        .select()
        .single();

    return _moduleFromRow(row, row['id'] as String);
  }

  /// Update a module
  Future<ModuleModel> updateModule(
    String courseId,
    String moduleId,
    Map<String, dynamic> updates,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoModules.indexWhere((m) => m.id == moduleId);
      if (index == -1) throw Exception('Module not found');

      final current = _demoModules[index];
      final updated = ModuleModel(
        id: current.id,
        courseId: current.courseId,
        title: updates['title'] as String? ?? current.title,
        description: updates['description'] as String? ?? current.description,
        order: updates['order'] as int? ?? current.order,
        isPublished: updates['isPublished'] as bool? ?? current.isPublished,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _demoModules[index] = updated;
      return updated;
    }

    final dbUpdates = <String, dynamic>{};
    if (updates.containsKey('title')) dbUpdates['title'] = updates['title'];
    if (updates.containsKey('description')) {
      dbUpdates['description'] = updates['description'];
    }
    if (updates.containsKey('order')) {
      dbUpdates['sort_order'] = updates['order'];
    }
    if (updates.containsKey('isPublished')) {
      dbUpdates['is_published'] = updates['isPublished'];
    }
    dbUpdates['updated_at'] = DateTime.now().toIso8601String();

    await _supabase!
        .from(_modulesTable)
        .update(dbUpdates)
        .eq('course_id', courseId)
        .eq('id', moduleId);

    final updated = await getModule(courseId, moduleId);
    if (updated == null) throw Exception('Failed to fetch updated module');
    return updated;
  }

  /// Delete a module
  Future<void> deleteModule(String courseId, String moduleId) async {
    if (EnvironmentConfig.isDemoMode) {
      _demoModules.removeWhere((m) => m.id == moduleId);
      _demoLessons.removeWhere((l) => l.moduleId == moduleId);
      return;
    }

    // Delete all lessons in module first
    final lessons = await getLessons(courseId, moduleId: moduleId);
    for (final lesson in lessons) {
      await deleteLesson(courseId, lesson.id);
    }

    await _supabase!
        .from(_modulesTable)
        .delete()
        .eq('course_id', courseId)
        .eq('id', moduleId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lesson Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all lessons for a course or module
  Future<List<LessonModel>> getLessons(
    String courseId, {
    String? moduleId,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      var lessons = _demoLessons.where((l) => l.courseId == courseId);
      if (moduleId != null) {
        lessons = lessons.where((l) => l.moduleId == moduleId);
      }
      final list = lessons.toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    }

    var query = _supabase!.from(_lessonsTable).select().eq('course_id', courseId);

    if (moduleId != null) {
      query = query.eq('module_id', moduleId);
    }

    final rows = await query.order('sort_order');
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => _lessonFromRow(row, row['id'] as String))
        .toList();
  }

  /// Get a single lesson
  Future<LessonModel?> getLesson(String courseId, String lessonId) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoLessons.firstWhere((l) => l.id == lessonId);
      } catch (_) {
        return null; // Lesson not found in demo data
      }
    }

    final row = await _supabase!
        .from(_lessonsTable)
        .select()
        .eq('course_id', courseId)
        .eq('id', lessonId)
        .maybeSingle();

    if (row == null) return null;
    return _lessonFromRow(row, row['id'] as String);
  }

  /// Create a new lesson
  Future<LessonModel> createLesson({
    required String courseId,
    required String moduleId,
    required String title,
    String? description,
    required int order,
    required LessonType type,
    String? content,
    String? videoUrl,
    required int durationMinutes,
    bool isPublished = false,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      // Auto-create a default module if the specified one doesn't exist
      final moduleExists = _demoModules.any(
        (m) => m.id == moduleId && m.courseId == courseId,
      );
      if (!moduleExists) {
        final existingModules = _demoModules
            .where((m) => m.courseId == courseId)
            .toList();
        if (existingModules.isEmpty) {
          final defaultModule = ModuleModel(
            id: moduleId,
            courseId: courseId,
            title: 'Course Content',
            order: 0,
            isPublished: true,
            createdAt: now,
          );
          _demoModules.add(defaultModule);
        }
      }

      final lesson = LessonModel(
        id: 'lesson-${DateTime.now().millisecondsSinceEpoch}',
        courseId: courseId,
        moduleId: moduleId,
        title: title,
        description: description,
        order: order,
        type: type,
        content: content,
        videoUrl: videoUrl,
        durationMinutes: durationMinutes,
        isPublished: isPublished,
        createdAt: now,
      );
      _demoLessons.add(lesson);
      return lesson;
    }

    final existingModule = await getModule(courseId, moduleId);
    if (existingModule == null) {
      await _supabase!.from(_modulesTable).insert({
        'id': moduleId,
        'course_id': courseId,
        'title': 'Course Content',
        'sort_order': 0,
        'is_published': true,
        'created_at': now.toIso8601String(),
      });
    }

    final row = await _supabase!
        .from(_lessonsTable)
        .insert({
          'course_id': courseId,
          'module_id': moduleId,
          'title': title,
          'description': description,
          'sort_order': order,
          'lesson_type': type.name,
          'content': content,
          'video_url': videoUrl,
          'duration_minutes': durationMinutes,
          'is_published': isPublished,
          'created_at': now.toIso8601String(),
        })
        .select()
        .single();

    return _lessonFromRow(row, row['id'] as String);
  }

  /// Update a lesson
  Future<LessonModel> updateLesson(
    String courseId,
    String lessonId,
    Map<String, dynamic> updates,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoLessons.indexWhere((l) => l.id == lessonId);
      if (index == -1) throw Exception('Lesson not found');

      final current = _demoLessons[index];
      final updated = LessonModel(
        id: current.id,
        courseId: current.courseId,
        moduleId: updates['moduleId'] as String? ?? current.moduleId,
        title: updates['title'] as String? ?? current.title,
        description: updates['description'] as String? ?? current.description,
        order: updates['order'] as int? ?? current.order,
        type: updates['type'] != null
            ? LessonType.fromString(updates['type'] as String)
            : current.type,
        content: updates['content'] as String? ?? current.content,
        videoUrl: updates['videoUrl'] as String? ?? current.videoUrl,
        durationMinutes:
            updates['durationMinutes'] as int? ?? current.durationMinutes,
        isPublished: updates['isPublished'] as bool? ?? current.isPublished,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _demoLessons[index] = updated;
      return updated;
    }

    final dbUpdates = <String, dynamic>{};
    if (updates.containsKey('moduleId')) dbUpdates['module_id'] = updates['moduleId'];
    if (updates.containsKey('title')) dbUpdates['title'] = updates['title'];
    if (updates.containsKey('description')) {
      dbUpdates['description'] = updates['description'];
    }
    if (updates.containsKey('order')) dbUpdates['sort_order'] = updates['order'];
    if (updates.containsKey('type')) dbUpdates['lesson_type'] = updates['type'] is LessonType ? (updates['type'] as LessonType).name : updates['type'];
    if (updates.containsKey('content')) dbUpdates['content'] = updates['content'];
    if (updates.containsKey('videoUrl')) dbUpdates['video_url'] = updates['videoUrl'];
    if (updates.containsKey('durationMinutes')) {
      dbUpdates['duration_minutes'] = updates['durationMinutes'];
    }
    if (updates.containsKey('isPublished')) {
      dbUpdates['is_published'] = updates['isPublished'];
    }
    dbUpdates['updated_at'] = DateTime.now().toIso8601String();

    await _supabase!
        .from(_lessonsTable)
        .update(dbUpdates)
        .eq('course_id', courseId)
        .eq('id', lessonId);

    final updated = await getLesson(courseId, lessonId);
    if (updated == null) throw Exception('Failed to fetch updated lesson');
    return updated;
  }

  /// Delete a lesson
  Future<void> deleteLesson(String courseId, String lessonId) async {
    if (EnvironmentConfig.isDemoMode) {
      _demoLessons.removeWhere((l) => l.id == lessonId);
      _demoProgress.removeWhere((p) => p.lessonId == lessonId);
      return;
    }

    final attachmentRows = await _supabase!
        .from(_filesTable)
        .select('id, resource_kind, bucket, storage_path')
        .eq('course_id', courseId)
        .eq('lesson_id', lessonId);
    final attachments = (attachmentRows as List<dynamic>)
        .cast<Map<String, dynamic>>();

    if (attachments.isNotEmpty) {
      final pathsByBucket = <String, List<String>>{};
      for (final attachment in attachments) {
        if (attachment['resource_kind'] == 'url') continue;
        final bucket = attachment['bucket'] as String?;
        final storagePath = attachment['storage_path'] as String?;
        if (bucket == null ||
            bucket.isEmpty ||
            storagePath == null ||
            storagePath.isEmpty) {
          throw Exception(
            'An attached file has invalid storage information. '
            'The lesson was not deleted.',
          );
        }
        pathsByBucket.putIfAbsent(bucket, () => []).add(storagePath);
      }

      try {
        for (final entry in pathsByBucket.entries) {
          // Supabase Storage accepts at most 1,000 paths per remove request.
          for (var start = 0; start < entry.value.length; start += 1000) {
            final end = (start + 1000).clamp(0, entry.value.length);
            await _supabase.storage
                .from(entry.key)
                .remove(entry.value.sublist(start, end));
          }
        }
      } catch (error) {
        throw Exception(
          'Could not delete the attached files from storage. '
          'The lesson was not deleted. Please try again. ($error)',
        );
      }

      try {
        final deletedFiles = await _supabase
            .from(_filesTable)
            .delete()
            .eq('course_id', courseId)
            .eq('lesson_id', lessonId)
            .select('id');
        if ((deletedFiles as List<dynamic>).length != attachments.length) {
          throw Exception('Not all attached file records could be deleted.');
        }
      } catch (error) {
        throw Exception(
          'The files were removed from storage, but their records could not '
          'be cleaned up. Please retry the lesson deletion. ($error)',
        );
      }
    }

    final deletedLessons = await _supabase
        .from(_lessonsTable)
        .delete()
        .eq('course_id', courseId)
        .eq('id', lessonId)
        .select('id');
    if ((deletedLessons as List<dynamic>).isEmpty) {
      throw Exception(
        'The lesson could not be deleted. Check your instructor permissions '
        'and try again.',
      );
    }
  }

  /// Toggle lesson publish status
  Future<LessonModel> toggleLessonPublish(
    String courseId,
    String lessonId,
    bool publish,
  ) async {
    return updateLesson(courseId, lessonId, {'isPublished': publish});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Progress Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get lesson progress for a user
  Future<LessonProgressModel?> getLessonProgress(
    String lessonId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      try {
        return _demoProgress.firstWhere(
          (p) => p.lessonId == lessonId && p.userId == userId,
        );
      } catch (_) {
        return null;
      }
    }

    final row = await _supabase!
        .from(_lessonProgressTable)
        .select()
        .eq('lesson_id', lessonId)
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return _progressFromRow(row, row['id'] as String);
  }

  /// Get all lesson progress for a course enrollment
  Future<List<LessonProgressModel>> getCourseProgress(
    String courseId,
    String enrollmentId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      return _demoProgress
          .where((p) => p.enrollmentId == enrollmentId)
          .toList();
    }

    final rows = await _supabase!
      .from(_lessonProgressTable)
      .select()
      .eq('enrollment_id', enrollmentId);

    return (rows as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map((row) => _progressFromRow(row, row['id'] as String))
      .toList();
  }

  /// Gets a student's saved progress for the supplied lessons in one query.
  Future<List<LessonProgressModel>> getLessonProgressForLessons({
    required List<String> lessonIds,
    required String userId,
  }) async {
    if (lessonIds.isEmpty) return const [];

    if (EnvironmentConfig.isDemoMode) {
      return _demoProgress
          .where(
            (progress) =>
                progress.userId == userId && lessonIds.contains(progress.lessonId),
          )
          .toList();
    }

    final rows = await _supabase!
        .from(_lessonProgressTable)
        .select()
        .eq('user_id', userId)
        .inFilter('lesson_id', lessonIds);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => _progressFromRow(row, row['id'] as String))
        .toList();
  }

  /// Mark a lesson as complete
  Future<LessonProgressModel> markLessonComplete({
    required String courseId,
    required String lessonId,
    required String enrollmentId,
    required String userId,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final existingIndex = _demoProgress.indexWhere(
        (p) => p.lessonId == lessonId && p.userId == userId,
      );

      if (existingIndex != -1) {
        final updated = _demoProgress[existingIndex].copyWith(
          isCompleted: true,
          completedAt: now,
          lastAccessedAt: now,
        );
        _demoProgress[existingIndex] = updated;
        return updated;
      }

      final progress = LessonProgressModel(
        id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
        lessonId: lessonId,
        enrollmentId: enrollmentId,
        userId: userId,
        isCompleted: true,
        completedAt: now,
        lastAccessedAt: now,
      );
      _demoProgress.add(progress);
      return progress;
    }

    final existing = await getLessonProgress(lessonId, userId);

    final data = {
      'lesson_id': lessonId,
      'enrollment_id': enrollmentId,
      'user_id': userId,
      'is_completed': true,
      'completed_at': now.toIso8601String(),
      'last_accessed_at': now.toIso8601String(),
    };

    if (existing != null) {
      await _supabase!
          .from(_lessonProgressTable)
          .update(data)
          .eq('id', existing.id);
      return existing.copyWith(
        isCompleted: true,
        completedAt: now,
        lastAccessedAt: now,
      );
    }

    final row = await _supabase!
        .from(_lessonProgressTable)
        .insert(data)
        .select()
        .single();

    return _progressFromRow(row, row['id'] as String);
  }

  /// Mark a previously completed lesson as incomplete without losing access data.
  Future<LessonProgressModel> markLessonIncomplete({
    required String courseId,
    required String lessonId,
    required String enrollmentId,
    required String userId,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final existingIndex = _demoProgress.indexWhere(
        (progress) => progress.lessonId == lessonId && progress.userId == userId,
      );

      if (existingIndex != -1) {
        final existing = _demoProgress[existingIndex];
        final updated = LessonProgressModel(
          id: existing.id,
          lessonId: existing.lessonId,
          enrollmentId: existing.enrollmentId,
          userId: existing.userId,
          isCompleted: false,
          lastAccessedAt: now,
          savedState: existing.savedState,
        );
        _demoProgress[existingIndex] = updated;
        return updated;
      }
    }

    final data = {
      'lesson_id': lessonId,
      'enrollment_id': enrollmentId,
      'user_id': userId,
      'is_completed': false,
      'completed_at': null,
      'last_accessed_at': now.toIso8601String(),
    };
    final existing = EnvironmentConfig.isDemoMode
        ? null
        : await getLessonProgress(lessonId, userId);

    if (existing != null) {
      await _supabase!
          .from(_lessonProgressTable)
          .update(data)
          .eq('id', existing.id);
      return LessonProgressModel(
        id: existing.id,
        lessonId: existing.lessonId,
        enrollmentId: existing.enrollmentId,
        userId: existing.userId,
        isCompleted: false,
        lastAccessedAt: now,
        savedState: existing.savedState,
      );
    }

    if (EnvironmentConfig.isDemoMode) {
      final progress = LessonProgressModel(
        id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
        lessonId: lessonId,
        enrollmentId: enrollmentId,
        userId: userId,
        isCompleted: false,
        lastAccessedAt: now,
      );
      _demoProgress.add(progress);
      return progress;
    }

    final row = await _supabase!
        .from(_lessonProgressTable)
        .insert(data)
        .select()
        .single();
    return _progressFromRow(row, row['id'] as String);
  }

  /// Update lesson access time
  Future<void> updateLessonAccess({
    required String courseId,
    required String lessonId,
    required String enrollmentId,
    required String userId,
    Map<String, dynamic>? savedState,
  }) async {
    final now = DateTime.now();

    if (EnvironmentConfig.isDemoMode) {
      final existingIndex = _demoProgress.indexWhere(
        (p) => p.lessonId == lessonId && p.userId == userId,
      );

      if (existingIndex != -1) {
        _demoProgress[existingIndex] = _demoProgress[existingIndex].copyWith(
          lastAccessedAt: now,
          savedState: savedState,
        );
      } else {
        _demoProgress.add(
          LessonProgressModel(
            id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
            lessonId: lessonId,
            enrollmentId: enrollmentId,
            userId: userId,
            isCompleted: false,
            lastAccessedAt: now,
            savedState: savedState,
          ),
        );
      }
      return;
    }

    final existing = await getLessonProgress(lessonId, userId);

    final data = {
      'lesson_id': lessonId,
      'enrollment_id': enrollmentId,
      'user_id': userId,
      'last_accessed_at': now.toIso8601String(),
      'saved_state': savedState,
    };

    if (existing != null) {
      await _supabase!
          .from(_lessonProgressTable)
          .update(data)
          .eq('id', existing.id);
    } else {
      data['is_completed'] = false;
      await _supabase!.from(_lessonProgressTable).insert(data);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get next and previous lesson IDs
  Future<Map<String, String?>> getAdjacentLessons(
    String courseId,
    String lessonId,
  ) async {
    final lessons = await getLessons(courseId);
    final modules = await getModules(courseId);

    // Sort lessons by module order, then lesson order
    lessons.sort((a, b) {
      final moduleA = modules.firstWhere((m) => m.id == a.moduleId);
      final moduleB = modules.firstWhere((m) => m.id == b.moduleId);
      if (moduleA.order != moduleB.order) {
        return moduleA.order.compareTo(moduleB.order);
      }
      return a.order.compareTo(b.order);
    });

    final currentIndex = lessons.indexWhere((l) => l.id == lessonId);

    return {
      'previous': currentIndex > 0 ? lessons[currentIndex - 1].id : null,
      'next': currentIndex < lessons.length - 1
          ? lessons[currentIndex + 1].id
          : null,
    };
  }

  /// Get total duration of a course in minutes
  Future<int> getCourseDuration(String courseId) async {
    final lessons = await getLessons(courseId);
    return lessons.fold<int>(0, (sum, l) => sum + l.durationMinutes);
  }

  /// Get completion percentage for a course
  Future<double> getCourseCompletionPercentage(
    String courseId,
    String enrollmentId,
  ) async {
    final lessons = await getLessons(courseId);
    if (lessons.isEmpty) return 0.0;

    final progress = await getCourseProgress(courseId, enrollmentId);
    final completedCount = progress.where((p) => p.isCompleted).length;

    return completedCount / lessons.length;
  }
}
