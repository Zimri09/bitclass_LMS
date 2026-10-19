import 'dart:typed_data';
import 'package:file_picker/file_picker.dart' as fp;
import 'upload_picker_options.dart'
    if (dart.library.js_interop) 'upload_picker_options_web.dart';

const maxCourseUploadBytes = 50 * 1024 * 1024;

Future<fp.PlatformFile?> pickUploadFile({List<String>? extensions}) =>
    fp.FilePicker.pickFile(
      type: extensions == null ? fp.FileType.any : fp.FileType.custom,
      allowedExtensions: extensions,
      webOptions: uploadPickerOptions,
    );

/// Validate the actual byte count, never rounded MB or unavailable size metadata.
void validateUploadBytes(Uint8List bytes, {required int maxBytes}) {
  if (bytes.isEmpty) {
    throw const FormatException(
      'The selected file is empty (0 bytes). Choose a file with content.',
    );
  }
  if (bytes.length > maxBytes) {
    throw FormatException(
      'This file exceeds the maximum size of ${maxBytes ~/ (1024 * 1024)} MB.',
    );
  }
}

Future<Uint8List> readUploadFile(
  fp.PlatformFile file, {
  required int maxBytes,
}) async {
  // Size metadata may be absent on virtual/cloud-backed files. Read bytes before
  // treating an unknown size as empty, but reject known oversized files early.
  int? size;
  try {
    size = await file.length();
  } catch (_) {
    /* Validate actual bytes below. */
  }
  if (size != null && size > maxBytes) {
    throw FormatException(
      'This file exceeds the maximum size of ${maxBytes ~/ (1024 * 1024)} MB.',
    );
  }
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    throw const FormatException(
      'Could not read the selected file. Download it to your device and try again.',
    );
  }
  validateUploadBytes(bytes, maxBytes: maxBytes);
  return bytes;
}

String uploadMimeType(String fileName, {String? fallback}) {
  const mimes = <String, String>{
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'mp4': 'video/mp4',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'aac': 'audio/aac',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    '7z': 'application/x-7z-compressed',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    'dart': 'text/x-dart',
    'py': 'text/x-python',
    'js': 'application/javascript',
    'ts': 'text/typescript',
    'html': 'text/html',
    'css': 'text/css',
    'json': 'application/json',
    'xml': 'application/xml',
    'yaml': 'application/yaml',
    'yml': 'application/yaml',
    'md': 'text/markdown',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };
  final name = fileName.trim();
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return mimes[extension] ??
      (fallback?.trim().isNotEmpty == true
          ? fallback!.trim().toLowerCase()
          : 'application/octet-stream');
}
