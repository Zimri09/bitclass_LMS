import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import '../../helpers/upload_picker_fake.dart';
import 'package:bitclass/core/utils/upload_file.dart';
import 'package:bitclass/core/errors/app_error.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content beats misleading filenames and MIME hints', () {
    expect(
      detectUploadMimeType(
        'photo.png',
        Uint8List.fromList(utf8.encode('%PDF-1.7')),
        reportedMimeType: 'image/png',
      ),
      'application/pdf',
    );
    expect(
      detectUploadMimeType(
        'report.pdf',
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ),
      'image/png',
    );
    expect(
      detectUploadMimeType(
        'report.pdf',
        Uint8List.fromList(utf8.encode('Plain text')),
      ),
      'text/plain',
    );
    expect(
      detectUploadMimeType('photo.png', Uint8List.fromList([0, 1, 2, 3])),
      'application/octet-stream',
    );
    expect(
      detectUploadMimeType(
        'no-extension',
        Uint8List.fromList([0, 1, 2, 3]),
        reportedMimeType: 'video/custom',
      ),
      'video/custom',
    );
  });
  test('Office types come from archive metadata, not the extension', () {
    for (final entry in {
      'word/document.xml': 'docx',
      'ppt/presentation.xml': 'pptx',
      'xl/workbook.xml': 'xlsx',
    }.entries) {
      final archive = Archive()
        ..add(ArchiveFile('[Content_Types].xml', 4, utf8.encode('<x/>')))
        ..add(ArchiveFile(entry.key, 4, utf8.encode('<x/>')));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(
        detectUploadMimeType('unknown.zip', bytes),
        uploadMimeType('file.${entry.value}'),
      );
    }
    final zip = Archive()..add(ArchiveFile('readme.txt', 2, utf8.encode('Hi')));
    expect(
      detectUploadMimeType(
        'fake.docx',
        Uint8List.fromList(ZipEncoder().encode(zip)),
      ),
      'application/zip',
    );
  });
  test(
    'picker reads every file and preserves per-file limits and item caps',
    () async {
      final previous = FilePickerPlatform.instance;
      final picker = UploadPickerFake([
        MemoryUploadFile('one.txt', utf8.encode('Hello')),
        MemoryUploadFile('two.pdf', utf8.encode('%PDF-1.7')),
      ]);
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = previous);
      final files = await pickUploadData(maxBytes: 10, maxFiles: 2);
      expect(files.map((file) => file.name), ['one.txt', 'two.pdf']);
      expect(files.map((file) => file.mimeType), [
        'text/plain',
        'application/pdf',
      ]);
      expect(files.map((file) => file.bytes.length), [5, 8]);
      await expectLater(
        pickUploadData(maxBytes: 10, maxFiles: 1),
        throwsFormatException,
      );
      await expectLater(pickUploadData(maxBytes: 6), throwsFormatException);
      picker.files = [MemoryUploadFile('empty.txt', [])];
      await expectLater(pickUploadData(maxBytes: 10), throwsFormatException);
      picker.files = [];
      expect(await pickUploadData(maxBytes: 10), isEmpty);
    },
  );
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
