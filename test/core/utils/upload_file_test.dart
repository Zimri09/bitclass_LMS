import 'dart:typed_data';
import 'package:bitclass/core/utils/upload_file.dart';
import 'package:bitclass/core/errors/app_error.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nonempty uploads below 1 MB have no minimum-size restriction', () {
    for (final size in [1, 17, 1023, 1024, 999999, 1048575]) {
      validateUploadBytes(Uint8List(size), maxBytes: 1048576);
    }
    validateUploadBytes(Uint8List(1048576), maxBytes: 1048576);
    expect(
      () => validateUploadBytes(Uint8List(1048577), maxBytes: 1048576),
      throwsFormatException,
    );
    expect(
      () => validateUploadBytes(Uint8List(0), maxBytes: 1048576),
      throwsFormatException,
    );
  });
  test('unknown file length is not treated as an empty file', () async {
    expect(await readUploadFile(_File(0, [65]), maxBytes: 10), [65]);
    expect(await readUploadFile(_File(null, [65]), maxBytes: 10), [65]);
    await expectLater(
      readUploadFile(_File(0, List.filled(11, 65)), maxBytes: 10),
      throwsFormatException,
    );
  });
  test('canonical document MIME types override unreliable browser hints', () {
    expect(
      uploadMimeType('notes.TXT', fallback: 'application/octet-stream'),
      'text/plain',
    );
    expect(
      uploadMimeType('handout.DOCX ', fallback: 'application/zip'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(uploadMimeType('unknown.custom'), 'application/octet-stream');
  });
  test('upload errors explain the failure without changing permissions', () {
    expect(
      uploadErrorMessage('mime type not supported'),
      contains('file type'),
    );
    expect(
      uploadErrorMessage('403 row-level security'),
      contains('permission'),
    );
    expect(uploadErrorMessage('413 EntityTooLarge'), contains('limit'));
    expect(uploadErrorMessage('Failed to fetch'), noInternetConnectionMessage);
  });
}

final class _File extends PlatformFile {
  _File(this.size, List<int> content) : bytes = Uint8List.fromList(content);
  final int? size;
  final Uint8List bytes;
  @override
  String get name => 'notes.txt';
  @override
  Uri get uri => Uri.parse('memory:notes.txt');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  Future<int> length() async => size ?? (throw StateError('Unknown size'));
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}
