import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/utils/url_utils.dart';
import '../models/models.dart';

/// Repository handling file upload operations.
class FileRepository {
  static const String _filesTable = 'files';
  static const String _offlineFilesBox = 'bitclass_offline_files_v1';
  String get _storageBucket => EnvironmentConfig.storageBucket;

  final SupabaseClient? _supabase;
  final Dio _dio;
  final Future<Directory> Function() _supportDirectoryProvider;

  // Demo files for testing UI
  final List<CourseFile> _demoFiles = [];

  // Stream controller for real-time updates
  final _filesController = StreamController<List<CourseFile>>.broadcast();

  FileRepository({
    SupabaseClient? supabase,
    Dio? dio,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _supabase = EnvironmentConfig.isDemoMode
           ? null
           : (supabase ?? Supabase.instance.client),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(minutes: 5),
               sendTimeout: const Duration(seconds: 20),
             ),
           ),
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  Future<Box<dynamic>> _offlineBox() => Hive.openBox<dynamic>(_offlineFilesBox);

  String _offlineKey(String userId, String fileId) => '$userId::$fileId';

  String _safePathSegment(String value, {int maxLength = 100}) {
    var safe = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    if (safe.isEmpty) safe = 'file';
    if (safe.length > maxLength) safe = safe.substring(0, maxLength);
    return safe;
  }

  Future<List<OfflineCourseFile>> getOfflineFiles(String userId) async {
    final box = await _offlineBox();
    final files = <OfflineCourseFile>[];
    final staleKeys = <dynamic>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      try {
        final offline = OfflineCourseFile.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (offline.userId != userId) continue;
        if (await File(offline.localPath).exists()) {
          files.add(offline);
        } else {
          staleKeys.add(key);
        }
      } catch (_) {
        if (key.toString().startsWith('$userId::')) staleKeys.add(key);
      }
    }

    if (staleKeys.isNotEmpty) await box.deleteAll(staleKeys);
    files.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return files;
  }

  Future<OfflineCourseFile?> getOfflineFile(
    String userId,
    String fileId,
  ) async {
    final box = await _offlineBox();
    final key = _offlineKey(userId, fileId);
    final raw = box.get(key);
    if (raw is! Map) return null;

    try {
      final offline = OfflineCourseFile.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (offline.userId != userId || !await File(offline.localPath).exists()) {
        await box.delete(key);
        return null;
      }
      return offline;
    } catch (_) {
      await box.delete(key);
      return null;
    }
  }

  /// Downloads a material into app-private storage and persists its index.
  Future<OfflineCourseFile> downloadForOffline({
    required String userId,
    required CourseFile file,
    ValueChanged<double>? onProgress,
  }) async {
    if (file.isExternalLink) {
      throw Exception('Web links cannot be downloaded. Use Open Link instead.');
    }
    final existing = await getOfflineFile(userId, file.id);
    if (existing != null) return existing;

    final uri = Uri.tryParse(file.url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('This learning material has an invalid URL.');
    }

    final supportDirectory = await _supportDirectoryProvider();
    final targetDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}offline_files'
      '${Platform.pathSeparator}${_safePathSegment(userId)}'
      '${Platform.pathSeparator}${_safePathSegment(file.courseId)}',
    );
    await targetDirectory.create(recursive: true);

    final localName =
        '${_safePathSegment(file.id, maxLength: 48)}_'
        '${_safePathSegment(file.name, maxLength: 120)}';
    final localPath =
        '${targetDirectory.path}${Platform.pathSeparator}$localName';
    final partialPath = '$localPath.part';
    final partialFile = File(partialPath);
    final destination = File(localPath);

    try {
      if (await partialFile.exists()) await partialFile.delete();
      await _dio.download(
        file.url,
        partialPath,
        deleteOnError: true,
        options: Options(receiveDataWhenStatusError: false),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );

      if (!await partialFile.exists() || await partialFile.length() == 0) {
        throw Exception('The downloaded file was empty.');
      }

      if (await destination.exists()) await destination.delete();
      await partialFile.rename(localPath);

      final offline = OfflineCourseFile(
        userId: userId,
        file: file,
        localPath: localPath,
        downloadedAt: DateTime.now().toUtc(),
      );
      final box = await _offlineBox();
      await box.put(_offlineKey(userId, file.id), offline.toJson());
      onProgress?.call(1);
      return offline;
    } catch (_) {
      if (await partialFile.exists()) await partialFile.delete();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<void> openOfflineFile(OfflineCourseFile offline) async {
    final localFile = File(offline.localPath);
    if (!await localFile.exists()) {
      final box = await _offlineBox();
      await box.delete(_offlineKey(offline.userId, offline.file.id));
      throw Exception(
        'This offline file is no longer available on the device.',
      );
    }

    final result = await OpenFilex.open(offline.localPath);
    if (result.type != ResultType.done) {
      throw Exception(
        result.message.isEmpty
            ? 'No compatible app could open this file.'
            : result.message,
      );
    }
  }

  Future<void> removeOfflineFile({
    required String userId,
    required String fileId,
  }) async {
    final box = await _offlineBox();
    final key = _offlineKey(userId, fileId);
    final raw = box.get(key);

    if (raw is Map) {
      try {
        final offline = OfflineCourseFile.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (offline.userId == userId) {
          final localFile = File(offline.localPath);
          if (await localFile.exists()) await localFile.delete();
        }
      } catch (_) {
        // Invalid metadata is removed below.
      }
    }

    await box.delete(key);
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
      'resourceKind': row['resource_kind'] ?? 'file',
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

  /// Saves an external HTTP(S) link as a course or lesson resource.
  Future<CourseFile> createUrlResource({
    required String courseId,
    String? lessonId,
    required String name,
    required String url,
    required String description,
    required String uploaderId,
    required String uploaderName,
  }) async {
    final displayName = name.trim();
    if (displayName.isEmpty) {
      throw Exception('Please enter a name for this web link.');
    }
    final canonicalUrl = normalizeWebUrl(url).toString();
    final fileId = const Uuid().v4();

    if (EnvironmentConfig.isDemoMode) {
      final duplicate = _demoFiles.any(
        (file) =>
            file.courseId == courseId &&
            file.lessonId == lessonId &&
            file.isExternalLink &&
            file.url == canonicalUrl,
      );
      if (duplicate) {
        throw Exception('This URL has already been added here.');
      }

      final resource = CourseFile(
        id: fileId,
        courseId: courseId,
        lessonId: lessonId,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        name: displayName,
        description: description.trim(),
        url: canonicalUrl,
        resourceKind: CourseResourceKind.url,
        type: FileType.other,
        mimeType: 'text/uri-list',
        sizeBytes: 0,
        createdAt: DateTime.now(),
      );
      _demoFiles.add(resource);
      return resource;
    }

    var duplicateQuery = _supabase!
        .from(_filesTable)
        .select('id')
        .eq('course_id', courseId)
        .eq('resource_kind', CourseResourceKind.url.name)
        .eq('public_url', canonicalUrl);
    duplicateQuery = lessonId == null
        ? duplicateQuery.isFilter('lesson_id', null)
        : duplicateQuery.eq('lesson_id', lessonId);
    final duplicateRows = await duplicateQuery.limit(1);
    if ((duplicateRows as List<dynamic>).isNotEmpty) {
      throw Exception('This URL has already been added here.');
    }

    try {
      final row = await _supabase
          .from(_filesTable)
          .insert({
            'id': fileId,
            'course_id': courseId,
            'lesson_id': lessonId,
            'uploader_id': uploaderId,
            'uploader_name': uploaderName,
            'name': displayName,
            'description': description.trim(),
            'resource_kind': CourseResourceKind.url.name,
            'bucket': null,
            'storage_path': null,
            'public_url': canonicalUrl,
            'thumbnail_url': null,
            'file_type': FileType.other.name,
            'mime_type': 'text/uri-list',
            'size_bytes': 0,
            'download_count': 0,
          })
          .select()
          .single();
      return _fileFromRow(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('This URL has already been added here.');
      }
      rethrow;
    }
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
    // The deployed files table may use a UUID primary key. UUIDs are also
    // valid when a newer database stores this identifier as text.
    final fileId = const Uuid().v4();
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

    String? storagePath;
    var uploadedToStorage = false;

    try {
      final extension = fileName.split('.').last;
      final fileType = CourseFile.getTypeFromExtension(extension);
      storagePath = '$courseId/$fileId-$fileName';

      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.processing,
        progress: 0.85,
        startedAt: startTime,
      );

      try {
        await _supabase!.storage
            .from(_storageBucket)
            .uploadBinary(
              storagePath,
              fileData,
              fileOptions: FileOptions(contentType: mimeType, upsert: false),
            );
      } catch (e) {
        throw Exception('Storage upload failed: $e');
      }
      uploadedToStorage = true;

      final publicUrl = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(storagePath);

      try {
        await _supabase.from(_filesTable).insert({
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
      } catch (e) {
        throw Exception('File record save failed: $e');
      }

      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.completed,
        progress: 1.0,
        startedAt: startTime,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      // Do not leave an unreachable object behind when the metadata insert
      // fails because of a database policy or connectivity error.
      if (uploadedToStorage && storagePath != null) {
        try {
          await _supabase!.storage.from(_storageBucket).remove([storagePath]);
        } catch (_) {
          // Preserve the original upload error; the object can be removed
          // later from the Storage dashboard if this cleanup also fails.
        }
      }
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
    final fileId = const Uuid().v4();
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
    if (row == null) {
      throw Exception('The learning material could not be found.');
    }

    final isExternalLink = row['resource_kind'] == CourseResourceKind.url.name;
    final bucket = row['bucket'] as String? ?? _storageBucket;
    final storagePath = row['storage_path'] as String?;
    if (!isExternalLink && (storagePath == null || storagePath.isEmpty)) {
      throw Exception('The learning material has an invalid storage path.');
    }

    if (!isExternalLink) {
      try {
        await _supabase!.storage.from(bucket).remove([storagePath!]);
      } catch (error) {
        throw Exception(
          'Could not delete the file from storage. The learning material was '
          'kept so you can retry. ($error)',
        );
      }
    }

    final deletedRows = await _supabase!
        .from(_filesTable)
        .delete()
        .eq('course_id', courseId)
        .eq('id', fileId)
        .select('id');
    if ((deletedRows as List<dynamic>).isEmpty) {
      throw Exception(
        'The file was removed from storage, but its record could not be '
        'deleted. Please retry.',
      );
    }

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        await removeOfflineFile(userId: currentUserId, fileId: fileId);
      } catch (_) {
        // Remote deletion succeeded; local stale metadata can be pruned later.
      }
    }
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
