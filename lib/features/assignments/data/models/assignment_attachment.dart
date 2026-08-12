import 'package:equatable/equatable.dart';

enum AssignmentAttachmentKind {
  file,
  link;

  static AssignmentAttachmentKind fromString(String value) {
    return AssignmentAttachmentKind.values.firstWhere(
      (kind) => kind.name == value.toLowerCase(),
      orElse: () => AssignmentAttachmentKind.file,
    );
  }
}

/// A file or web link attached to an assignment or student submission.
class AssignmentAttachment extends Equatable {
  final String id;
  final String name;
  final AssignmentAttachmentKind kind;
  final String? url;
  final String? storagePath;
  final String? mimeType;
  final int sizeBytes;

  const AssignmentAttachment({
    required this.id,
    required this.name,
    required this.kind,
    this.url,
    this.storagePath,
    this.mimeType,
    this.sizeBytes = 0,
  });

  bool get isFile => kind == AssignmentAttachmentKind.file;
  bool get isLink => kind == AssignmentAttachmentKind.link;
  bool get isStoredFile => isFile && (storagePath?.isNotEmpty ?? false);

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory AssignmentAttachment.fromMap(Map<String, dynamic> map) {
    return AssignmentAttachment(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Attachment',
      kind: AssignmentAttachmentKind.fromString(
        map['kind'] as String? ?? 'file',
      ),
      url: map['url'] as String?,
      storagePath: (map['storagePath'] ?? map['storage_path']) as String?,
      mimeType: (map['mimeType'] ?? map['mime_type']) as String?,
      sizeBytes:
          ((map['sizeBytes'] ?? map['size_bytes']) as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kind': kind.name,
      'url': url,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    url,
    storagePath,
    mimeType,
    sizeBytes,
  ];
}
