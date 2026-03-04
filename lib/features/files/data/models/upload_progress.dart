/// Status of file upload
enum UploadStatus {
  pending,
  uploading,
  processing,
  completed,
  failed,
  cancelled,
}

/// Model tracking upload progress for a file
class UploadProgress {
  final String fileId;
  final String fileName;
  final UploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const UploadProgress({
    required this.fileId,
    required this.fileName,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  /// Percentage progress as int (0-100)
  int get progressPercent => (progress * 100).toInt();

  /// Whether upload is still in progress
  bool get isInProgress =>
      status == UploadStatus.pending ||
      status == UploadStatus.uploading ||
      status == UploadStatus.processing;

  /// Whether upload completed successfully
  bool get isCompleted => status == UploadStatus.completed;

  /// Whether upload failed
  bool get isFailed => status == UploadStatus.failed;

  UploadProgress copyWith({
    String? fileId,
    String? fileName,
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return UploadProgress(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
