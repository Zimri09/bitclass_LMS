import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'upload_picker_options.dart'
    if (dart.library.js_interop) 'upload_picker_options_web.dart';

const maxCourseUploadBytes = 50 * 1024 * 1024;

class UploadFileData {
  final String name;
  final String mimeType;
  final Uint8List bytes;
  const UploadFileData({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
}

Future<List<fp.PlatformFile>> pickUploadFiles({List<String>? extensions}) =>
    fp.FilePicker.pickFiles(
      type: extensions == null ? fp.FileType.any : fp.FileType.custom,
      allowedExtensions: extensions,
      webOptions: uploadPickerOptions,
    );

Future<List<UploadFileData>> pickUploadData({
  required int maxBytes,
  int? maxFiles,
  List<String>? extensions,
  int Function(String name)? maxBytesForFile,
}) async {
  final files = await pickUploadFiles(extensions: extensions);
  if (maxFiles != null && files.length > maxFiles) {
    throw FormatException(
      'You can add $maxFiles more files. Select fewer files.',
    );
  }
  final result = <UploadFileData>[];
  for (final file in files) {
    try {
      final bytes = await readUploadFile(
        file,
        maxBytes: maxBytesForFile?.call(file.name) ?? maxBytes,
      );
      String? reportedMime;
      try {
        reportedMime = file.xFile.mimeType;
      } catch (_) {}
      result.add(
        UploadFileData(
          name: file.name,
          bytes: bytes,
          mimeType: detectUploadMimeType(
            file.name,
            bytes,
            reportedMimeType: reportedMime,
          ),
        ),
      );
    } catch (error) {
      throw FormatException('${file.name}: $error');
    }
  }
  return result;
}

/// Content signatures take precedence over platform MIME hints and filenames.
/// Office ZIP containers are inspected without decompressing their entries.
String detectUploadMimeType(
  String name,
  Uint8List bytes, {
  String? reportedMimeType,
}) {
  bool starts(List<int> magic) =>
      bytes.length >= magic.length &&
      List.generate(
        magic.length,
        (index) => bytes[index] == magic[index],
      ).every((value) => value);
  String asciiAt(int start, int end) =>
      bytes.length >= end ? latin1.decode(bytes.sublist(start, end)) : '';
  if (starts([0x1f, 0x8b])) return 'application/gzip';
  if (starts([0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c])) {
    return 'application/x-7z-compressed';
  }
  if (starts([0x52, 0x61, 0x72, 0x21, 0x1a, 0x07])) {
    return 'application/x-rar-compressed';
  }
  if (asciiAt(257, 262) == 'ustar') return 'application/x-tar';
  if (asciiAt(0, 2) == 'BM') return 'image/bmp';
  if (asciiAt(0, 4) == 'RIFF' && asciiAt(8, 12) == 'AVI ') {
    return 'video/x-msvideo';
  }
  if (asciiAt(4, 8) == 'ftyp' && asciiAt(8, 12) == 'qt  ') {
    return 'video/quicktime';
  }
  if (starts([0x1a, 0x45, 0xdf, 0xa3])) {
    if (reportedMimeType?.startsWith('audio/') == true) {
      return reportedMimeType!;
    }
    return latin1.decode(bytes.take(4096).toList()).contains('webm')
        ? 'video/webm'
        : 'video/x-matroska';
  }
  // Legacy Office files expose typed, UTF-16 directory entries in CFB storage.
  if (starts([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])) {
    final data = ByteData.sublistView(bytes);
    for (var offset = 512; offset + 128 <= bytes.length; offset += 128) {
      if (bytes[offset + 66] != 2) continue;
      final length = data.getUint16(offset + 64, Endian.little);
      if (length < 2 || length > 64 || length.isOdd) continue;
      final streamName = String.fromCharCodes([
        for (var i = 0; i < length - 2; i += 2)
          data.getUint16(offset + i, Endian.little),
      ]);
      if (streamName == 'WordDocument') return 'application/msword';
      if (streamName == 'Workbook' || streamName == 'Book') {
        return 'application/vnd.ms-excel';
      }
      if (streamName == 'PowerPoint Document') {
        return 'application/vnd.ms-powerpoint';
      }
    }
  }
  if (starts([0xff, 0xfe]) || starts([0xfe, 0xff])) return 'text/plain';
  final signature = lookupMimeType('', headerBytes: bytes);
  if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
    try {
      final directory = ZipDirectory()..read(InputMemoryStream(bytes));
      final names = directory.fileHeaders.map((file) => file.filename).toSet();
      if (names.contains('[Content_Types].xml')) {
        if (names.contains('word/document.xml')) {
          return uploadMimeType('file.docx');
        }
        if (names.contains('ppt/presentation.xml')) {
          return uploadMimeType('file.pptx');
        }
        if (names.contains('xl/workbook.xml')) {
          return uploadMimeType('file.xlsx');
        }
      }
    } catch (_) {
      /* A malformed archive is not an Office document. */
    }
    return 'application/zip';
  }
  if (signature != null && signature != 'application/octet-stream') {
    return signature == 'audio/x-wav' ? 'audio/wav' : signature;
  }
  final hint = reportedMimeType?.split(';').first.trim().toLowerCase();
  final sample = bytes.take(8192).toList();
  var text = utf8.decode(sample, allowMalformed: true);
  // A bounded sample can end in the middle of a valid UTF-8 character.
  if (bytes.length > sample.length) {
    text = text.replaceFirst(RegExp(r'\uFFFD$'), '');
  }
  if (sample.isNotEmpty &&
      !sample.any((b) => b < 32 && b != 9 && b != 10 && b != 13) &&
      !text.contains('\uFFFD')) {
    if (RegExp(
      r'<svg(?:\s|>)',
      caseSensitive: false,
    ).hasMatch(text.trimLeft())) {
      return 'image/svg+xml';
    }
    if (text.trimLeft().startsWith(r'{\rtf')) return 'application/rtf';
    final candidate = uploadMimeType(name);
    if (candidate.startsWith('text/') ||
        const {
          'application/json',
          'application/xml',
          'application/javascript',
          'application/yaml',
        }.contains(candidate)) {
      return candidate;
    }
    return 'text/plain';
  }
  if (hint != null &&
      hint.contains('/') &&
      hint != 'application/octet-stream') {
    return hint;
  }
  return 'application/octet-stream';
}

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
    'java': 'text/x-java-source',
    'c': 'text/x-c',
    'cpp': 'text/x-c++src',
    'h': 'text/x-c',
    'cs': 'text/x-csharp',
    'go': 'text/x-go',
    'rs': 'text/x-rust',
    'rb': 'text/x-ruby',
    'php': 'text/x-php',
    'swift': 'text/x-swift',
    'kt': 'text/x-kotlin',
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
