import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Base class for all file events
abstract class FileEvent extends Equatable {
  const FileEvent();

  @override
  List<Object?> get props => [];
}

/// Load files for a course
class LoadCourseFiles extends FileEvent {
  final String courseId;

  const LoadCourseFiles({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}

/// Load files for a specific lesson
class LoadLessonFiles extends FileEvent {
  final String courseId;
  final String lessonId;

  const LoadLessonFiles({required this.courseId, required this.lessonId});

  @override
  List<Object?> get props => [courseId, lessonId];
}

/// Upload a new file
class UploadFile extends FileEvent {
  final String courseId;
  final String? lessonId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String description;
  final String uploaderId;
  final String uploaderName;

  const UploadFile({
    required this.courseId,
    this.lessonId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.description = '',
    required this.uploaderId,
    required this.uploaderName,
  });

  @override
  List<Object?> get props => [
    courseId,
    lessonId,
    fileName,
    mimeType,
    fileSize,
    description,
    uploaderId,
    uploaderName,
  ];
}

/// Delete a file
class DeleteFile extends FileEvent {
  final String fileId;
  final String courseId;

  const DeleteFile({required this.fileId, required this.courseId});

  @override
  List<Object?> get props => [fileId, courseId];
}

/// Update file metadata
class UpdateFile extends FileEvent {
  final String courseId;
  final String fileId;
  final String? name;
  final String? description;

  const UpdateFile({
    required this.courseId,
    required this.fileId,
    this.name,
    this.description,
  });

  @override
  List<Object?> get props => [courseId, fileId, name, description];
}

/// Record file download
class RecordDownload extends FileEvent {
  final String courseId;
  final String fileId;

  const RecordDownload({required this.courseId, required this.fileId});

  @override
  List<Object?> get props => [courseId, fileId];
}

/// Search files
class SearchFiles extends FileEvent {
  final String courseId;
  final String query;

  const SearchFiles({required this.courseId, required this.query});

  @override
  List<Object?> get props => [courseId, query];
}

/// Filter files by type
class FilterFilesByType extends FileEvent {
  final String courseId;
  final FileType? type; // null means show all

  const FilterFilesByType({required this.courseId, this.type});

  @override
  List<Object?> get props => [courseId, type];
}

/// Clear current filter
class ClearFileFilter extends FileEvent {
  final String courseId;

  const ClearFileFilter({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}
