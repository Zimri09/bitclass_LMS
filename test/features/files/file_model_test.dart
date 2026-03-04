import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/files/data/models/file_model.dart';

void main() {
  group('CourseFile', () {
    test('creates a valid file with all fields', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'document.pdf',
        description: 'A test document',
        url: 'https://example.com/document.pdf',
        type: FileType.document,
        mimeType: 'application/pdf',
        sizeBytes: 1024 * 1024, // 1 MB
        downloadCount: 10,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(file.id, 'file-1');
      expect(file.name, 'document.pdf');
      expect(file.type, FileType.document);
      expect(file.downloadCount, 10);
    });

    test('formattedSize returns correct format for bytes', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'small.txt',
        url: 'https://example.com/small.txt',
        type: FileType.document,
        mimeType: 'text/plain',
        sizeBytes: 500,
        createdAt: DateTime.now(),
      );

      expect(file.formattedSize, '500 B');
    });

    test('formattedSize returns correct format for kilobytes', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'medium.txt',
        url: 'https://example.com/medium.txt',
        type: FileType.document,
        mimeType: 'text/plain',
        sizeBytes: 2048,
        createdAt: DateTime.now(),
      );

      expect(file.formattedSize, '2.0 KB');
    });

    test('formattedSize returns correct format for megabytes', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'large.zip',
        url: 'https://example.com/large.zip',
        type: FileType.archive,
        mimeType: 'application/zip',
        sizeBytes: 5 * 1024 * 1024,
        createdAt: DateTime.now(),
      );

      expect(file.formattedSize, '5.0 MB');
    });

    test('extension extracts correct file extension', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'code.dart',
        url: 'https://example.com/code.dart',
        type: FileType.code,
        mimeType: 'text/x-dart',
        sizeBytes: 1024,
        createdAt: DateTime.now(),
      );

      expect(file.extension, 'dart');
    });

    test('getTypeFromExtension returns correct types', () {
      expect(CourseFile.getTypeFromExtension('pdf'), FileType.document);
      expect(CourseFile.getTypeFromExtension('doc'), FileType.document);
      expect(CourseFile.getTypeFromExtension('docx'), FileType.document);
      expect(CourseFile.getTypeFromExtension('jpg'), FileType.image);
      expect(CourseFile.getTypeFromExtension('png'), FileType.image);
      expect(CourseFile.getTypeFromExtension('gif'), FileType.image);
      expect(CourseFile.getTypeFromExtension('mp4'), FileType.video);
      expect(CourseFile.getTypeFromExtension('mov'), FileType.video);
      expect(CourseFile.getTypeFromExtension('mp3'), FileType.audio);
      expect(CourseFile.getTypeFromExtension('wav'), FileType.audio);
      expect(CourseFile.getTypeFromExtension('dart'), FileType.code);
      expect(CourseFile.getTypeFromExtension('py'), FileType.code);
      expect(CourseFile.getTypeFromExtension('js'), FileType.code);
      expect(CourseFile.getTypeFromExtension('zip'), FileType.archive);
      expect(CourseFile.getTypeFromExtension('rar'), FileType.archive);
      expect(CourseFile.getTypeFromExtension('unknown'), FileType.other);
    });

    test('toJson creates valid map', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'test.pdf',
        description: 'Test file',
        url: 'https://example.com/test.pdf',
        type: FileType.document,
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        downloadCount: 5,
        createdAt: DateTime(2024, 1, 1),
      );

      final json = file.toJson();

      expect(json['id'], 'file-1');
      expect(json['name'], 'test.pdf');
      expect(json['type'], 'document');
      expect(json['sizeBytes'], 1024);
    });

    test('fromJson creates valid file', () {
      final json = {
        'id': 'file-1',
        'courseId': 'course-1',
        'uploaderId': 'user-1',
        'uploaderName': 'Test User',
        'name': 'test.pdf',
        'description': 'Test file',
        'url': 'https://example.com/test.pdf',
        'type': 'document',
        'mimeType': 'application/pdf',
        'sizeBytes': 1024,
        'downloadCount': 5,
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final file = CourseFile.fromJson(json);

      expect(file.id, 'file-1');
      expect(file.name, 'test.pdf');
      expect(file.type, FileType.document);
      expect(file.sizeBytes, 1024);
    });

    test('copyWith creates new instance with updated fields', () {
      final file = CourseFile(
        id: 'file-1',
        courseId: 'course-1',
        uploaderId: 'user-1',
        uploaderName: 'Test User',
        name: 'original.pdf',
        url: 'https://example.com/original.pdf',
        type: FileType.document,
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        createdAt: DateTime(2024, 1, 1),
      );

      final updatedFile = file.copyWith(name: 'renamed.pdf', downloadCount: 10);

      expect(updatedFile.name, 'renamed.pdf');
      expect(updatedFile.downloadCount, 10);
      expect(updatedFile.id, file.id);
      expect(updatedFile.courseId, file.courseId);
    });
  });

  group('FileType enum', () {
    test('has all expected values', () {
      expect(FileType.values.length, 7);
      expect(FileType.values.contains(FileType.document), true);
      expect(FileType.values.contains(FileType.image), true);
      expect(FileType.values.contains(FileType.video), true);
      expect(FileType.values.contains(FileType.audio), true);
      expect(FileType.values.contains(FileType.code), true);
      expect(FileType.values.contains(FileType.archive), true);
      expect(FileType.values.contains(FileType.other), true);
    });
  });
}
