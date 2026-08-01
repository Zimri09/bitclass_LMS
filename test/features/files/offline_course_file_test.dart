import 'package:bitclass/features/files/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline file metadata survives a Hive-compatible map round trip', () {
    final downloadedAt = DateTime.utc(2026, 8, 1, 13, 30);
    final file = CourseFile(
      id: '8b07cb2d-34a7-4c20-bc11-e42fcce655ae',
      courseId: 'course-1',
      lessonId: 'lesson-1',
      uploaderId: 'teacher-1',
      uploaderName: 'Mr. Instructor',
      name: 'chapter-1.pdf',
      description: 'Chapter one notes',
      url: 'https://example.com/chapter-1.pdf',
      type: FileType.document,
      mimeType: 'application/pdf',
      sizeBytes: 2048,
      createdAt: DateTime.utc(2026, 7, 30),
    );
    final offline = OfflineCourseFile(
      userId: 'student-1',
      file: file,
      localPath: '/private/offline/chapter-1.pdf',
      downloadedAt: downloadedAt,
    );

    final restored = OfflineCourseFile.fromJson(offline.toJson());

    expect(restored.userId, 'student-1');
    expect(restored.file.id, file.id);
    expect(restored.file.name, 'chapter-1.pdf');
    expect(restored.file.lessonId, 'lesson-1');
    expect(restored.localPath, offline.localPath);
    expect(restored.downloadedAt, downloadedAt);
  });
}
