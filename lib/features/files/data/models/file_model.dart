/// Types of files that can be uploaded
enum FileType { document, image, video, audio, code, archive, other }

/// Model representing an uploaded file/course material
class CourseFile {
  final String id;
  final String courseId;
  final String? lessonId;
  final String uploaderId;
  final String uploaderName;
  final String name;
  final String description;
  final String url;
  final String? thumbnailUrl;
  final FileType type;
  final String mimeType;
  final int sizeBytes;
  final int downloadCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CourseFile({
    required this.id,
    required this.courseId,
    this.lessonId,
    required this.uploaderId,
    required this.uploaderName,
    required this.name,
    this.description = '',
    required this.url,
    this.thumbnailUrl,
    required this.type,
    required this.mimeType,
    required this.sizeBytes,
    this.downloadCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get human readable file size
  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file extension from name
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Determine file type from extension
  static FileType getTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
      case 'rtf':
      case 'odt':
        return FileType.document;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
      case 'bmp':
        return FileType.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'webm':
        return FileType.video;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'aac':
      case 'flac':
        return FileType.audio;
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'h':
      case 'cs':
      case 'go':
      case 'rs':
      case 'rb':
      case 'php':
      case 'swift':
      case 'kt':
      case 'html':
      case 'css':
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return FileType.code;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return FileType.archive;
      default:
        return FileType.other;
    }
  }

  factory CourseFile.fromJson(Map<String, dynamic> json) {
    return CourseFile(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      lessonId: json['lessonId'] as String?,
      uploaderId: json['uploaderId'] as String,
      uploaderName: json['uploaderName'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      type: FileType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FileType.other,
      ),
      mimeType: json['mimeType'] as String,
      sizeBytes: json['sizeBytes'] as int,
      downloadCount: json['downloadCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'lessonId': lessonId,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'name': name,
      'description': description,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'type': type.name,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'downloadCount': downloadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from Firestore document map
  factory CourseFile.fromMap(Map<String, dynamic> map, String id) {
    return CourseFile.fromJson({...map, 'id': id});
  }

  /// Convert to Firestore document map
  Map<String, dynamic> toMap() => toJson();

  CourseFile copyWith({
    String? id,
    String? courseId,
    String? lessonId,
    String? uploaderId,
    String? uploaderName,
    String? name,
    String? description,
    String? url,
    String? thumbnailUrl,
    FileType? type,
    String? mimeType,
    int? sizeBytes,
    int? downloadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourseFile(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderName: uploaderName ?? this.uploaderName,
      name: name ?? this.name,
      description: description ?? this.description,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadCount: downloadCount ?? this.downloadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
