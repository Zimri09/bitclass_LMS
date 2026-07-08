import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/models.dart';

/// Repository handling file upload operations.
class FileRepository {
  static const String _filesTable = 'files';
  static const String _storageBucket = 'materials';

  final SupabaseClient? _supabase;

  // Demo files for testing UI
  final List<CourseFile> _demoFiles = [];

  // Stream controller for real-time updates
  final _filesController = StreamController<List<CourseFile>>.broadcast();

  FileRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  void _initDemoData() {
    _demoFiles.addAll([
      CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'instructor-1',
        uploaderName: 'Prof. Sarah Chen',
        name: 'Week1_Introduction.pdf',
        description: 'Course introduction and syllabus overview',
        url: 'https://example.com/files/week1-intro.pdf',
        type: FileType.document,
        mimeType: 'application/pdf',
        sizeBytes: 2457600,
        downloadCount: 45,
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      CourseFile(
        id: 'file-2',
        courseId: 'course-1',
        lessonId: 'lesson-1',
        uploaderId: 'instructor-1',
        uploaderName: 'Prof. Sarah Chen',
        name: 'dart_basics.dart',
        description: 'Sample Dart code demonstrating basic syntax',
        url: 'https://example.com/files/dart_basics.dart',
        type: FileType.code,
        mimeType: 'text/x-dart',
        sizeBytes: 4096,
        downloadCount: 32,
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      CourseFile(
        id: 'file-3',
        courseId: 'course-1',
        uploaderId: 'instructor-1',
        uploaderName: 'Prof. Sarah Chen',
        name: 'flutter_architecture.png',
        description: 'Flutter architecture diagram',
        url: 'https://example.com/files/flutter_architecture.png',
        thumbnailUrl:
            'https://example.com/files/flutter_architecture_thumb.png',
        type: FileType.image,
        mimeType: 'image/png',
        sizeBytes: 524288,
        downloadCount: 28,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      CourseFile(
        id: 'file-4',
        courseId: 'course-1',
        uploaderId: 'instructor-1',
        uploaderName: 'Prof. Sarah Chen',
        name: 'state_management_lecture.mp4',
        description: 'Recorded lecture on state management patterns',
        url: 'https://example.com/files/state_management.mp4',
        thumbnailUrl: 'https://example.com/files/state_management_thumb.jpg',
        type: FileType.video,
        mimeType: 'video/mp4',
        sizeBytes: 157286400,
        downloadCount: 18,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      CourseFile(
        id: 'file-5',
        courseId: 'course-1',
        uploaderId: 'instructor-1',
        uploaderName: 'Prof. Sarah Chen',
        name: 'project_starter.zip',
        description: 'Starter code for the course project',
        url: 'https://example.com/files/project_starter.zip',
        type: FileType.archive,
        mimeType: 'application/zip',
        sizeBytes: 8388608,
        downloadCount: 52,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      CourseFile(
        id: 'file-6',
        courseId: 'course-2',
        uploaderId: 'instructor-2',
        uploaderName: 'Dr. Michael Torres',
        name: 'api_design_notes.md',
        description: 'Notes on RESTful API design principles',
        url: 'https://example.com/files/api_design.md',
        type: FileType.document,
        mimeType: 'text/markdown',
        sizeBytes: 12288,
        downloadCount: 15,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ]);
  }

  Map<String, dynamic> _rowToFileMap(Map<String, dynamic> row) {
    return {
      'courseId': row['course_id'],
      'lessonId': row['lesson_id'],
      'uploaderId': row['uploader_id'],
      'uploaderName': row['uploader_name'],
      'name': row['name'],
      'description': row['description'],
      'url': row['public_url'],
      'thumbnailUrl': row['thumbnail_url'],
      'type': row['file_type'],
      'mimeType': row['mime_type'],
      'sizeBytes': row['size_bytes'],
      'downloadCount': row['download_count'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  CourseFile _fileFromRow(Map<String, dynamic> row) {
    return CourseFile.fromMap(_rowToFileMap(row), row['id'] as String);
  }

  Future<Map<String, dynamic>?> _getFileRow(
    String courseId,
    String fileId,
  ) async {
    return await _supabase!
        .from(_filesTable)
        .select()
        .eq('course_id', courseId)
        .eq('id', fileId)
        .maybeSingle();
  }

  /// Get all files for a course
  Future<List<CourseFile>> getCourseFiles(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _demoFiles.where((f) => f.courseId == courseId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final rows = await _supabase!
        .from(_filesTable)
        .select()
        .eq('course_id', courseId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_fileFromRow)
        .toList();
  }

  /// Get files for a specific lesson
  Future<List<CourseFile>> getLessonFiles(
    String courseId,
    String lessonId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _demoFiles
          .where((f) => f.courseId == courseId && f.lessonId == lessonId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final rows = await _supabase!
        .from(_filesTable)
        .select()
        .eq('course_id', courseId)
        .eq('lesson_id', lessonId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_fileFromRow)
        .toList();
  }

  /// Get single file by ID
  Future<CourseFile?> getFile(String courseId, String fileId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        return _demoFiles.firstWhere((f) => f.id == fileId);
      } catch (_) {
        return null;
      }
    }

    final row = await _getFileRow(courseId, fileId);
    if (row == null) return null;
    return _fileFromRow(row);
  }

  /// Stream of files for real-time updates
  Stream<List<CourseFile>> watchCourseFiles(String courseId) {
    if (EnvironmentConfig.isDemoMode) {
      getCourseFiles(courseId).then((files) {
        if (!_filesController.isClosed) {
          _filesController.add(files);
        }
      });
      return _filesController.stream;
    }

    return _supabase!
        .from(_filesTable)
        .stream(primaryKey: ['id'])
        .eq('course_id', courseId)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows.cast<Map<String, dynamic>>().map(_fileFromRow).toList(),
        );
  }

  /// Upload a file with real data
  Stream<UploadProgress> uploadFileWithData({
    required String courseId,
    String? lessonId,
    required String fileName,
    required String mimeType,
    required Uint8List fileData,
    required String description,
    required String uploaderId,
    required String uploaderName,
  }) async* {
    final fileId = 'file-${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.uploading,
      progress: 0.0,
      startedAt: startTime,
    );

    if (EnvironmentConfig.isDemoMode) {
      for (var i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        yield UploadProgress(
          fileId: fileId,
          fileName: fileName,
          status: UploadStatus.uploading,
          progress: i / 10,
          startedAt: startTime,
        );
      }

      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.processing,
        progress: 1.0,
        startedAt: startTime,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final extension = fileName.split('.').last;
      final newFile = CourseFile(
        id: fileId,
        courseId: courseId,
        lessonId: lessonId,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        name: fileName,
        description: description,
        url: 'https://example.com/files/$fileId',
        type: CourseFile.getTypeFromExtension(extension),
        mimeType: mimeType,
        sizeBytes: fileData.length,
        createdAt: DateTime.now(),
      );

      _demoFiles.add(newFile);

      final files = await getCourseFiles(courseId);
      if (!_filesController.isClosed) {
        _filesController.add(files);
      }

      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.completed,
        progress: 1.0,
        startedAt: startTime,
        completedAt: DateTime.now(),
      );
      return;
    }

    try {
      final extension = fileName.split('.').last;
      final fileType = CourseFile.getTypeFromExtension(extension);
      final storagePath = '$courseId/$fileId-$fileName';

      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.processing,
        progress: 0.85,
        startedAt: startTime,
      );

      await _supabase!.storage
          .from(_storageBucket)
          .uploadBinary(
            storagePath,
            fileData,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      final publicUrl = _supabase!.storage
          .from(_storageBucket)
          .getPublicUrl(storagePath);

      await _supabase!.from(_filesTable).insert({
        'id': fileId,
        'course_id': courseId,
        'lesson_id': lessonId,
        'uploader_id': uploaderId,
        'uploader_name': uploaderName,
        'name': fileName,
        'description': description,
        'bucket': _storageBucket,
        'storage_path': storagePath,
        'public_url': publicUrl,
        'thumbnail_url': null,
        'file_type': fileType.name,
        'mime_type': mimeType,
        'size_bytes': fileData.length,
        'download_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.completed,
        progress: 1.0,
        startedAt: startTime,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.failed,
        progress: 0.0,
        startedAt: startTime,
        errorMessage: e.toString(),
      );
    }
  }

  /// Upload a file (legacy compatibility method).
  Stream<UploadProgress> uploadFile({
    required String courseId,
    String? lessonId,
    required String fileName,
    required String mimeType,
    required int fileSize,
    required String description,
    required String uploaderId,
    required String uploaderName,
  }) async* {
    final fileId = 'file-${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.uploading,
      progress: 0.0,
      startedAt: startTime,
    );

    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.uploading,
        progress: i / 10,
        startedAt: startTime,
      );
    }

    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.processing,
      progress: 1.0,
      startedAt: startTime,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    final extension = fileName.split('.').last;
    final newFile = CourseFile(
      id: fileId,
      courseId: courseId,
      lessonId: lessonId,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      name: fileName,
      description: description,
      url: 'https://example.com/files/$fileId',
      type: CourseFile.getTypeFromExtension(extension),
      mimeType: mimeType,
      sizeBytes: fileSize,
      createdAt: DateTime.now(),
    );

    if (EnvironmentConfig.isDemoMode) {
      _demoFiles.add(newFile);

      final files = await getCourseFiles(courseId);
      if (!_filesController.isClosed) {
        _filesController.add(files);
      }
    }

    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.completed,
      progress: 1.0,
      startedAt: startTime,
      completedAt: DateTime.now(),
    );
  }

  /// Delete a file
  Future<void> deleteFile(String courseId, String fileId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _demoFiles.removeWhere((f) => f.id == fileId);

      final files = await getCourseFiles(courseId);
      if (!_filesController.isClosed) {
        _filesController.add(files);
      }
      return;
    }

    final row = await _getFileRow(courseId, fileId);
    if (row != null) {
      try {
        await _supabase!.storage.from(_storageBucket).remove([
          row['storage_path'] as String,
        ]);
      } catch (e) {
        if (kDebugMode) {
          log('Could not delete file from storage: $e', name: 'FileRepository');
        }
      }
    }

    await _supabase!.from(_filesTable).delete().eq('id', fileId);
  }

  /// Increment download count
  Future<void> recordDownload(String courseId, String fileId) async {
    if (EnvironmentConfig.isDemoMode) {
      final index = _demoFiles.indexWhere((f) => f.id == fileId);
      if (index != -1) {
        final file = _demoFiles[index];
        _demoFiles[index] = file.copyWith(
          downloadCount: file.downloadCount + 1,
        );
      }
      return;
    }

    final row = await _getFileRow(courseId, fileId);
    if (row == null) return;

    final current = (row['download_count'] as num?)?.toInt() ?? 0;
    await _supabase!
        .from(_filesTable)
        .update({'download_count': current + 1})
        .eq('id', fileId);
  }

  /// Update file metadata
  Future<CourseFile> updateFile({
    required String courseId,
    required String fileId,
    String? name,
    String? description,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _demoFiles.indexWhere((f) => f.id == fileId);
      if (index == -1) {
        throw Exception('File not found');
      }

      final file = _demoFiles[index];
      final updatedFile = file.copyWith(
        name: name ?? file.name,
        description: description ?? file.description,
        updatedAt: DateTime.now(),
      );
      _demoFiles[index] = updatedFile;

      final files = await getCourseFiles(courseId);
      if (!_filesController.isClosed) {
        _filesController.add(files);
      }

      return updatedFile;
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    await _supabase!.from(_filesTable).update(updates).eq('id', fileId);

    final updatedFile = await getFile(courseId, fileId);
    if (updatedFile == null) {
      throw Exception('File not found after update');
    }
    return updatedFile;
  }

  /// Search files by name
  Future<List<CourseFile>> searchFiles(String courseId, String query) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final lowerQuery = query.toLowerCase();
      return _demoFiles
          .where(
            (f) =>
                f.courseId == courseId &&
                (f.name.toLowerCase().contains(lowerQuery) ||
                    f.description.toLowerCase().contains(lowerQuery)),
          )
          .toList();
    }

    final files = await getCourseFiles(courseId);
    final lowerQuery = query.toLowerCase();
    return files
        .where(
          (f) =>
              f.name.toLowerCase().contains(lowerQuery) ||
              f.description.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  /// Get files filtered by type
  Future<List<CourseFile>> getFilesByType(
    String courseId,
    FileType type,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _demoFiles
          .where((f) => f.courseId == courseId && f.type == type)
          .toList();
    }

    final rows = await _supabase!
        .from(_filesTable)
        .select()
        .eq('course_id', courseId)
        .eq('file_type', type.name);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_fileFromRow)
        .toList();
  }

  void dispose() {
    _filesController.close();
  }
}
