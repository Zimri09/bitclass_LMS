import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/models.dart';

/// Repository handling file upload operations
class FileRepository {
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  FileRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = EnvironmentConfig.isDemoMode
          ? null
          : (firestore ?? FirebaseFirestore.instance),
      _storage = EnvironmentConfig.isDemoMode
          ? null
          : (storage ?? FirebaseStorage.instance) {
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

  // Demo files for testing UI
  final List<CourseFile> _demoFiles = [];

  // Stream controller for real-time updates
  final _filesController = StreamController<List<CourseFile>>.broadcast();

  /// Get all files for a course
  Future<List<CourseFile>> getCourseFiles(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _demoFiles.where((f) => f.courseId == courseId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final snapshot = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CourseFile.fromMap(doc.data(), doc.id))
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

    final snapshot = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .where('lessonId', isEqualTo: lessonId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CourseFile.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get single file by ID
  Future<CourseFile?> getFile(String courseId, String fileId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        return _demoFiles.firstWhere((f) => f.id == fileId);
      } catch (_) {
        return null; // File not found in demo data
      }
    }

    final doc = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .doc(fileId)
        .get();

    if (!doc.exists) return null;
    return CourseFile.fromMap(doc.data()!, doc.id);
  }

  /// Stream of files for real-time updates
  Stream<List<CourseFile>> watchCourseFiles(String courseId) {
    if (EnvironmentConfig.isDemoMode) {
      // Emit initial data
      getCourseFiles(courseId).then((files) {
        if (!_filesController.isClosed) {
          _filesController.add(files);
        }
      });
      return _filesController.stream;
    }

    return _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CourseFile.fromMap(doc.data(), doc.id))
              .toList(),
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
      // Simulate upload progress
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

    // Real Firebase upload
    try {
      final storagePath =
          '${StoragePaths.materials}/$courseId/$fileId-$fileName';
      final ref = _storage!.ref().child(storagePath);

      final uploadTask = ref.putData(
        fileData,
        SettableMetadata(contentType: mimeType),
      );

      await for (final event in uploadTask.snapshotEvents) {
        final progress = event.bytesTransferred / event.totalBytes;
        yield UploadProgress(
          fileId: fileId,
          fileName: fileName,
          status: event.state == TaskState.running
              ? UploadStatus.uploading
              : UploadStatus.processing,
          progress: progress,
          startedAt: startTime,
        );
      }

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();

      // Save metadata to Firestore
      final extension = fileName.split('.').last;
      final newFile = CourseFile(
        id: fileId,
        courseId: courseId,
        lessonId: lessonId,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        name: fileName,
        description: description,
        url: downloadUrl,
        type: CourseFile.getTypeFromExtension(extension),
        mimeType: mimeType,
        sizeBytes: fileData.length,
        createdAt: DateTime.now(),
      );

      await _firestore!
          .collection(FirestorePaths.courses)
          .doc(courseId)
          .collection('files')
          .doc(fileId)
          .set(newFile.toMap());

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

  /// Upload a file (simulated for demo - legacy method)
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

    // Start upload
    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.uploading,
      progress: 0.0,
      startedAt: DateTime.now(),
    );

    // Simulate upload progress
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      yield UploadProgress(
        fileId: fileId,
        fileName: fileName,
        status: UploadStatus.uploading,
        progress: i / 10,
        startedAt: DateTime.now(),
      );
    }

    // Processing
    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.processing,
      progress: 1.0,
      startedAt: DateTime.now(),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    // Create the file
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

    _demoFiles.add(newFile);

    // Notify listeners
    final files = await getCourseFiles(courseId);
    if (!_filesController.isClosed) {
      _filesController.add(files);
    }

    // Completed
    yield UploadProgress(
      fileId: fileId,
      fileName: fileName,
      status: UploadStatus.completed,
      progress: 1.0,
      startedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
  }

  /// Delete a file
  Future<void> deleteFile(String courseId, String fileId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _demoFiles.removeWhere((f) => f.id == fileId);

      // Notify listeners
      final files = await getCourseFiles(courseId);
      if (!_filesController.isClosed) {
        _filesController.add(files);
      }
      return;
    }

    // Get file to delete from storage
    final file = await getFile(courseId, fileId);
    if (file != null) {
      // Delete from storage
      try {
        final ref = _storage!.refFromURL(file.url);
        await ref.delete();
      } catch (e) {
        // File might not exist in storage
        if (kDebugMode)
          log('Could not delete file from storage: $e', name: 'FileRepository');
      }
    }

    // Delete from Firestore
    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .doc(fileId)
        .delete();
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

    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .doc(fileId)
        .update({'downloadCount': FieldValue.increment(1)});
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

      // Notify listeners
      final files = await getCourseFiles(courseId);
      if (!_filesController.isClosed) {
        _filesController.add(files);
      }

      return updatedFile;
    }

    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .doc(fileId)
        .update(updates);

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

    // Firestore doesn't support full-text search, so fetch all and filter
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

    final snapshot = await _firestore!
        .collection(FirestorePaths.courses)
        .doc(courseId)
        .collection('files')
        .where('type', isEqualTo: type.name)
        .get();

    return snapshot.docs
        .map((doc) => CourseFile.fromMap(doc.data(), doc.id))
        .toList();
  }

  void dispose() {
    _filesController.close();
  }
}
