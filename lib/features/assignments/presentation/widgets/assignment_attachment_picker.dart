import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';

import '../../data/repositories/assignment_repository.dart';

class PickedAssignmentFile {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  const PickedAssignmentFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
}

Future<PickedAssignmentFile?> pickAssignmentFile() async {
  final file = await fp.FilePicker.pickFile(type: fp.FileType.any);
  if (file == null) return null;

  final fileSize = await file.length();
  if (fileSize > AssignmentRepository.maxAttachmentBytes) {
    throw Exception('Attachments must be 25 MB or smaller.');
  }

  final bytes = await file.readAsBytes();

  return PickedAssignmentFile(
    name: file.name,
    mimeType: assignmentMimeType(file.name),
    bytes: bytes,
  );
}

String assignmentMimeType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  const mimeTypes = <String, String>{
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'html': 'text/html',
    'css': 'text/css',
    'dart': 'text/x-dart',
    'py': 'text/x-python',
    'js': 'application/javascript',
    'ts': 'text/typescript',
    'json': 'application/json',
    'xml': 'application/xml',
    'yaml': 'application/yaml',
    'yml': 'application/yaml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'zip': 'application/zip',
    'gz': 'application/gzip',
    'tar': 'application/x-tar',
    'rar': 'application/x-rar-compressed',
    '7z': 'application/x-7z-compressed',
  };
  return mimeTypes[extension] ?? 'application/octet-stream';
}
