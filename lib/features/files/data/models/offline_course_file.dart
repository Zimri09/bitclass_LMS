import 'file_model.dart';

/// A course material saved in this user's private application storage.
class OfflineCourseFile {
  final String userId;
  final CourseFile file;
  final String localPath;
  final DateTime downloadedAt;

  const OfflineCourseFile({
    required this.userId,
    required this.file,
    required this.localPath,
    required this.downloadedAt,
  });

  factory OfflineCourseFile.fromJson(Map<String, dynamic> json) {
    return OfflineCourseFile(
      userId: json['userId'] as String,
      file: CourseFile.fromJson(Map<String, dynamic>.from(json['file'] as Map)),
      localPath: json['localPath'] as String,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'file': file.toJson(),
      'localPath': localPath,
      'downloadedAt': downloadedAt.toUtc().toIso8601String(),
    };
  }
}
