import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Base class for all file states
abstract class FileState extends Equatable {
  const FileState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class FileInitial extends FileState {
  const FileInitial();
}

/// Loading files
class FilesLoading extends FileState {
  const FilesLoading();
}

/// Files loaded successfully
class FilesLoaded extends FileState {
  final List<CourseFile> files;
  final FileType? filterType;
  final String? searchQuery;

  const FilesLoaded({required this.files, this.filterType, this.searchQuery});

  @override
  List<Object?> get props => [files, filterType, searchQuery];
}

/// Upload in progress
class FileUploading extends FileState {
  final UploadProgress progress;
  final List<CourseFile> existingFiles;

  const FileUploading({required this.progress, this.existingFiles = const []});

  @override
  List<Object?> get props => [progress, existingFiles];
}

/// File uploaded successfully
class FileUploaded extends FileState {
  final CourseFile file;

  const FileUploaded({required this.file});

  @override
  List<Object?> get props => [file];
}

/// File deleted successfully
class FileDeleted extends FileState {
  final String fileId;

  const FileDeleted({required this.fileId});

  @override
  List<Object?> get props => [fileId];
}

/// File updated successfully
class FileUpdated extends FileState {
  final CourseFile file;

  const FileUpdated({required this.file});

  @override
  List<Object?> get props => [file];
}

/// Error state
class FileError extends FileState {
  final String message;
  final List<CourseFile> existingFiles;

  const FileError({required this.message, this.existingFiles = const []});

  @override
  List<Object?> get props => [message, existingFiles];
}
