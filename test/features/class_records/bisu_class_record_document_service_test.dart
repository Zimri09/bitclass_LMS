import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bitclass/features/class_records/data/models/class_record_model.dart';
import 'package:bitclass/features/class_records/data/services/bisu_class_record_document_service.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports quiz and activity grades in a BISU class record', () async {
    final templateData = await rootBundle.load(
      BisuClassRecordDocumentService.templateAsset,
    );
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );
    final generated = const BisuClassRecordDocumentService()
        .generateFromTemplate(
          templateBytes: templateBytes,
          course: _course,
          record: _record,
          generatedAt: DateTime(2026, 8, 28, 18, 39),
        );
    final archive = ZipDecoder().decodeBytes(generated, verify: true);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content,
    );
    final headerXml = utf8.decode(
      archive.findFile('word/header2.xml')!.content,
    );

    for (final headerName in const [
      'word/header1.xml',
      'word/header2.xml',
      'word/header3.xml',
    ]) {
      expect(
        archive.files.where((file) => file.name == headerName),
        hasLength(1),
      );
      expect(
        utf8.decode(archive.findFile(headerName)!.content),
        contains('CLASS RECORD'),
      );
    }
    expect(headerXml, contains('BOHOL ISLAND STATE UNIVERSITY'));
    expect(headerXml, contains('CLASS RECORD'));
    expect(headerXml, isNot(contains('<w:t>ATTENDANCE</w:t>')));
    expect(documentXml, contains('Data Structures &amp; Algorithms'));
    expect(documentXml, contains('Ana &amp; Bea &lt;Student&gt;'));
    expect(documentXml, contains('Quiz Grade'));
    expect(documentXml, contains('Activity Grade'));
    expect(documentXml, contains('80.0%'));
    expect(documentXml, contains('92.5%'));
    expect(documentXml, contains('86.3%'));
    expect(documentXml, contains('August 28, 2026 at 6:39 PM'));
    expect(
      documentXml.indexOf('Ana &amp; Bea'),
      lessThan(documentXml.indexOf('Zoë Student')),
    );
  });

  test('splits a large class record into numbered pages', () async {
    final templateData = await rootBundle.load(
      BisuClassRecordDocumentService.templateAsset,
    );
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );
    final students = List.generate(
      19,
      (index) => StudentClassRecord(
        userId: 'student-${index + 1}',
        displayName: 'Student ${(index + 1).toString().padLeft(2, '0')}',
        quizGrade: 75,
        assignmentGrade: 80,
        overallGrade: 77.5,
      ),
    );
    final generated = const BisuClassRecordDocumentService()
        .generateFromTemplate(
          templateBytes: templateBytes,
          course: _course,
          record: CourseClassRecord(
            students: students,
            quizCount: 2,
            assignmentCount: 3,
            attendanceSessionCount: 0,
          ),
          generatedAt: DateTime(2026, 8, 28),
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

const _record = CourseClassRecord(
  students: [
    StudentClassRecord(
      userId: 'student-2',
      displayName: 'Zoë Student',
      quizGrade: 60,
      assignmentGrade: null,
      overallGrade: 60,
    ),
    StudentClassRecord(
      userId: 'student-1',
      displayName: 'Ana & Bea <Student>',
      quizGrade: 80,
      assignmentGrade: 92.5,
      overallGrade: 86.25,
    ),
  ],
  quizCount: 2,
  assignmentCount: 3,
  attendanceSessionCount: 0,
);
