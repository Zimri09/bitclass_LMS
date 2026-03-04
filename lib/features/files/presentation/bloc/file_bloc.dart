import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/file_repository.dart';
import 'file_event.dart';
import 'file_state.dart';

/// Bloc managing file operations
class FileBloc extends Bloc<FileEvent, FileState> {
  final FileRepository fileRepository;

  List<CourseFile> _currentFiles = [];
  StreamSubscription<UploadProgress>? _uploadSubscription;

  FileBloc({required this.fileRepository}) : super(const FileInitial()) {
    on<LoadCourseFiles>(_onLoadCourseFiles);
    on<LoadLessonFiles>(_onLoadLessonFiles);
    on<UploadFile>(_onUploadFile);
    on<DeleteFile>(_onDeleteFile);
    on<UpdateFile>(_onUpdateFile);
    on<RecordDownload>(_onRecordDownload);
    on<SearchFiles>(_onSearchFiles);
    on<FilterFilesByType>(_onFilterFilesByType);
    on<ClearFileFilter>(_onClearFileFilter);
  }

  Future<void> _onLoadCourseFiles(
    LoadCourseFiles event,
    Emitter<FileState> emit,
  ) async {
    emit(const FilesLoading());
    try {
      final files = await fileRepository.getCourseFiles(event.courseId);
      _currentFiles = files;
      emit(FilesLoaded(files: files));
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onLoadLessonFiles(
    LoadLessonFiles event,
    Emitter<FileState> emit,
  ) async {
    emit(const FilesLoading());
    try {
      final files = await fileRepository.getLessonFiles(
        event.courseId,
        event.lessonId,
      );
      _currentFiles = files;
      emit(FilesLoaded(files: files));
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onUploadFile(UploadFile event, Emitter<FileState> emit) async {
    try {
      await emit.forEach<UploadProgress>(
        fileRepository.uploadFile(
          courseId: event.courseId,
          lessonId: event.lessonId,
          fileName: event.fileName,
          mimeType: event.mimeType,
          fileSize: event.fileSize,
          description: event.description,
          uploaderId: event.uploaderId,
          uploaderName: event.uploaderName,
        ),
        onData: (progress) {
          if (progress.status == UploadStatus.completed) {
            // Reload files after upload
            add(LoadCourseFiles(courseId: event.courseId));
          }
          return FileUploading(
            progress: progress,
            existingFiles: _currentFiles,
          );
        },
        onError: (error, stackTrace) {
          return FileError(
            message: error.toString(),
            existingFiles: _currentFiles,
          );
        },
      );
    } catch (e) {
      emit(FileError(message: e.toString(), existingFiles: _currentFiles));
    }
  }

  Future<void> _onDeleteFile(DeleteFile event, Emitter<FileState> emit) async {
    try {
      await fileRepository.deleteFile(event.courseId, event.fileId);
      emit(FileDeleted(fileId: event.fileId));
      // Reload files
      add(LoadCourseFiles(courseId: event.courseId));
    } catch (e) {
      emit(FileError(message: e.toString(), existingFiles: _currentFiles));
    }
  }

  Future<void> _onUpdateFile(UpdateFile event, Emitter<FileState> emit) async {
    try {
      final updatedFile = await fileRepository.updateFile(
        courseId: event.courseId,
        fileId: event.fileId,
        name: event.name,
        description: event.description,
      );
      emit(FileUpdated(file: updatedFile));
    } catch (e) {
      emit(FileError(message: e.toString(), existingFiles: _currentFiles));
    }
  }

  Future<void> _onRecordDownload(
    RecordDownload event,
    Emitter<FileState> emit,
  ) async {
    await fileRepository.recordDownload(event.courseId, event.fileId);
  }

  Future<void> _onSearchFiles(
    SearchFiles event,
    Emitter<FileState> emit,
  ) async {
    emit(const FilesLoading());
    try {
      final files = await fileRepository.searchFiles(
        event.courseId,
        event.query,
      );
      emit(FilesLoaded(files: files, searchQuery: event.query));
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onFilterFilesByType(
    FilterFilesByType event,
    Emitter<FileState> emit,
  ) async {
    emit(const FilesLoading());
    try {
      List<CourseFile> files;
      if (event.type == null) {
        files = await fileRepository.getCourseFiles(event.courseId);
      } else {
        files = await fileRepository.getFilesByType(
          event.courseId,
          event.type!,
        );
      }
      emit(FilesLoaded(files: files, filterType: event.type));
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onClearFileFilter(
    ClearFileFilter event,
    Emitter<FileState> emit,
  ) async {
    add(LoadCourseFiles(courseId: event.courseId));
  }

  @override
  Future<void> close() {
    _uploadSubscription?.cancel();
    return super.close();
  }
}
