import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bitclass/features/attendance/data/models/attendance_models.dart';
import 'package:bitclass/features/attendance/data/services/bisu_attendance_document_service.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generates an editable attendance form and preserves the BISU header',
    () async {
      final templateData = await rootBundle.load(
        BisuAttendanceDocumentService.templateAsset,
      );
      final templateBytes = templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      );
      final generated = const BisuAttendanceDocumentService()
          .generateFromTemplate(
            templateBytes: templateBytes,
            course: _course,
            sessions: [_session],
            records: [_presentRecord, _excusedRecord],
            roster: const [
              CourseRosterMember(
                userId: 'student-2',
                displayName: 'Zoë & Co <Student>',
              ),
              CourseRosterMember(
                userId: 'student-1',
                displayName: 'Ana Student',
              ),
            ],
            generatedAt: DateTime(2026, 8, 27, 9, 30),
          );

      final sourceArchive = ZipDecoder().decodeBytes(
        templateBytes,
        verify: true,
      );
      final generatedArchive = ZipDecoder().decodeBytes(
        generated,
        verify: true,
      );
      final sourceHeader = sourceArchive.findFile('word/header2.xml')!.content;
      final generatedHeader = generatedArchive
          .findFile('word/header2.xml')!
          .content;
      expect(listEquals(sourceHeader, generatedHeader), isTrue);
      expect(
        listEquals(
          generatedHeader,
          generatedArchive.findFile('word/header1.xml')!.content,
        ),
        isTrue,
      );
      expect(
        listEquals(
          generatedHeader,
          generatedArchive.findFile('word/header3.xml')!.content,
        ),
        isTrue,
      );

      final documentXml = utf8.decode(
        generatedArchive.findFile('word/document.xml')!.content,
      );
      expect(documentXml, contains('Data Structures &amp; Algorithms'));
      expect(documentXml, contains('Ana Student'));
      expect(documentXml, contains('Zoë &amp; Co &lt;Student&gt;'));
      expect(documentXml, contains('Medical &amp; family emergency'));
      expect(documentXml, contains('August 27, 2026'));
      expect(documentXml, contains('9:00 AM - 10:00 AM'));
      expect(documentXml, contains('P - Present'));
      expect(documentXml, isNot(contains('Zoë & Co <Student>')));

      expect(
        documentXml.indexOf('Ana Student'),
        lessThan(documentXml.indexOf('Zoë')),
      );
    },
  );

  test('splits large rosters into safe BISU pages', () async {
    final templateData = await rootBundle.load(
      BisuAttendanceDocumentService.templateAsset,
    );
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );
    final roster = List.generate(
      19,
      (index) => CourseRosterMember(
        userId: 'student-${index + 1}',
        displayName: 'Student ${(index + 1).toString().padLeft(2, '0')}',
      ),
    );

    final generated = const BisuAttendanceDocumentService()
        .generateFromTemplate(
          templateBytes: templateBytes,
          course: _course,
          sessions: [_session],
          records: const [],
          roster: roster,
          generatedAt: DateTime(2026, 8, 27),
        );
    final archive = ZipDecoder().decodeBytes(generated, verify: true);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content,
    );

    expect(
      RegExp(r'<w:pageBreakBefore/>').allMatches(documentXml),
      hasLength(1),
    );
    expect(documentXml, contains('1 of 2'));
    expect(documentXml, contains('2 of 2'));
    expect(documentXml, contains('Student 19'));
    expect(documentXml, contains('<w:t xml:space="preserve">19</w:t>'));
  });
}

final _course = CourseModel(
  id: 'course-1',
  title: 'Data Structures & Algorithms',
  description: 'BSCS 1A',
  category: 'Programming',
  instructorId: 'instructor-1',
  instructorName: 'Prof. Maria Santos',
  courseCode: 'ABC123',
  isPublished: true,
  createdAt: DateTime.utc(2026, 8, 1),
);

final _session = AttendanceSession(
  id: 'session-1',
  courseId: _course.id,
  attendanceDate: DateTime(2026, 8, 27),
  opensAt: DateTime(2026, 8, 27, 9),
  lateAt: DateTime(2026, 8, 27, 9, 15),
  closesAt: DateTime(2026, 8, 27, 10),
  createdBy: _course.instructorId,
  createdAt: DateTime.utc(2026, 8, 27),
);

final _presentRecord = AttendanceRecord(
  id: 'record-1',
  courseId: _course.id,
  sessionId: _session.id,
  studentId: 'student-1',
  attendanceDate: _session.attendanceDate,
  checkInAt: DateTime(2026, 8, 27, 8, 58),
  status: AttendanceStatus.present,
  createdBy: _course.instructorId,
  lastModifiedBy: 'student-1',
  createdAt: DateTime.utc(2026, 8, 27),
);

final _excusedRecord = AttendanceRecord(
  id: 'record-2',
  courseId: _course.id,
  sessionId: _session.id,
  studentId: 'student-2',
  attendanceDate: _session.attendanceDate,
  status: AttendanceStatus.excused,
  note: 'Medical & family emergency',
  createdBy: _course.instructorId,
  lastModifiedBy: _course.instructorId,
  createdAt: DateTime.utc(2026, 8, 27),
);
