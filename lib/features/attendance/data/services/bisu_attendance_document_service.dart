import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../courses/data/models/course_model.dart';
import '../models/attendance_models.dart';

/// Builds editable Word attendance forms while retaining the official BISU
/// heading, logos, page size, typography, and spacing from the supplied form.
class BisuAttendanceDocumentService {
  static const templateAsset = 'assets/templates/bisu_attendance_form.docx';
  static const _studentsPerPage = 12;

  const BisuAttendanceDocumentService();

  Future<Uint8List> generate({
    required CourseModel course,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required List<CourseRosterMember> roster,
    DateTime? generatedAt,
  }) async {
    final templateData = await rootBundle.load(templateAsset);
    return generateFromTemplate(
      templateBytes: templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      ),
      course: course,
      sessions: sessions,
      records: records,
      roster: roster,
      generatedAt: generatedAt,
    );
  }

  Uint8List generateFromTemplate({
    required Uint8List templateBytes,
    required CourseModel course,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required List<CourseRosterMember> roster,
    DateTime? generatedAt,
  }) {
    final archive = ZipDecoder().decodeBytes(templateBytes, verify: true);
    _validateTemplate(archive);
    _repeatOfficialHeaderOnEveryPage(archive);

    final sortedSessions = [...sessions]
      ..sort((a, b) => a.attendanceDate.compareTo(b.attendanceDate));
    final sortedRoster = [...roster]
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    final generated = (generatedAt ?? DateTime.now()).toLocal();
    final documentXml = _buildDocumentXml(
      course: course,
      sessions: sortedSessions,
      records: records,
      roster: sortedRoster,
      generatedAt: generated,
    );

    archive.add(ArchiveFile.string('word/document.xml', documentXml));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  void _repeatOfficialHeaderOnEveryPage(Archive archive) {
    final officialHeader = archive.findFile('word/header2.xml')!;
    final officialHeaderRelationships = archive.findFile(
      'word/_rels/header2.xml.rels',
    );

    for (final headerName in const ['header1.xml', 'header3.xml']) {
      archive.add(
        ArchiveFile(
          'word/$headerName',
          officialHeader.size,
          Uint8List.fromList(officialHeader.content),
        ),
      );
      if (officialHeaderRelationships != null) {
        archive.add(
          ArchiveFile(
            'word/_rels/$headerName.rels',
            officialHeaderRelationships.size,
            Uint8List.fromList(officialHeaderRelationships.content),
          ),
        );
      }
    }
  }

  void _validateTemplate(Archive archive) {
    final document = archive.findFile('word/document.xml');
    final header = archive.findFile('word/header2.xml');
    if (document == null || header == null) {
      throw const FormatException(
        'The BISU attendance template is missing required Word parts.',
      );
    }
    final headerXml = utf8.decode(header.content);
    if (!headerXml.contains('BOHOL ISLAND STATE UNIVERSITY') ||
        !headerXml.contains('ATTENDANCE')) {
      throw const FormatException(
        'The selected document is not the expected BISU attendance template.',
      );
    }
  }

  String _buildDocumentXml({
    required CourseModel course,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required List<CourseRosterMember> roster,
    required DateTime generatedAt,
  }) {
    final pages = <_AttendancePage>[];
    final sourceSessions = sessions.isEmpty
        ? const <AttendanceSession?>[null]
        : sessions.cast<AttendanceSession?>();
    final rosterPages = roster.isEmpty
        ? const <List<CourseRosterMember>>[[]]
        : _chunkRoster(roster);

    for (final session in sourceSessions) {
      for (var pageIndex = 0; pageIndex < rosterPages.length; pageIndex++) {
        pages.add(
          _AttendancePage(
            session: session,
            students: rosterPages[pageIndex],
            studentOffset: pageIndex * _studentsPerPage,
            partNumber: pageIndex + 1,
            partCount: rosterPages.length,
          ),
        );
      }
    }

    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      )
      ..write('<w:body>');

    for (var index = 0; index < pages.length; index++) {
      buffer.write(
        _buildPage(
          page: pages[index],
          course: course,
          records: records,
          generatedAt: generatedAt,
          pageBreakBefore: index > 0,
        ),
      );
    }

    buffer
      ..write(_sectionProperties())
      ..write('</w:body></w:document>');
    return buffer.toString();
  }

  List<List<CourseRosterMember>> _chunkRoster(List<CourseRosterMember> roster) {
    final chunks = <List<CourseRosterMember>>[];
    for (var start = 0; start < roster.length; start += _studentsPerPage) {
      final end = (start + _studentsPerPage).clamp(0, roster.length);
      chunks.add(roster.sublist(start, end));
    }
    return chunks;
  }

  String _buildPage({
    required _AttendancePage page,
    required CourseModel course,
    required List<AttendanceRecord> records,
    required DateTime generatedAt,
    required bool pageBreakBefore,
  }) {
    final dateFormat = DateFormat('MMMM d, y');
    final timeFormat = DateFormat('h:mm a');
    final session = page.session;
    final attendanceDate = session == null
        ? '________________'
        : dateFormat.format(session.attendanceDate.toLocal());
    final attendanceWindow = session == null
        ? '________________'
        : '${timeFormat.format(session.opensAt.toLocal())} - '
              '${timeFormat.format(session.closesAt.toLocal())}';
    final section = course.description.trim().isEmpty
        ? '________________'
        : course.description.trim();

    final buffer = StringBuffer()
      ..write(_headerClearance(pageBreakBefore: pageBreakBefore))
      ..write(
        _metadataTable(
          courseTitle: course.title,
          section: section,
          instructor: course.instructorName,
          courseCode: course.courseCode.isEmpty ? '-' : course.courseCode,
          attendanceDate: attendanceDate,
          attendanceWindow: attendanceWindow,
          pageLabel: page.partCount == 1
              ? '1 of 1'
              : '${page.partNumber} of ${page.partCount}',
          generatedAt: dateFormat.add_jm().format(generatedAt),
        ),
      )
      ..write(_spacer(100));

    final recordByStudent = <String, AttendanceRecord>{
      if (session != null)
        for (final record in records.where(
          (record) => record.sessionId == session.id,
        ))
          record.studentId: record,
    };

    final rows = <String>[];
    if (page.students.isEmpty) {
      for (var index = 0; index < 15; index++) {
        rows.add(
          _attendanceRow(
            number: '${index + 1}',
            studentName: '',
            status: '',
            checkIn: '',
            remarks: '',
          ),
        );
      }
    } else {
      for (var index = 0; index < page.students.length; index++) {
        final student = page.students[index];
        final record = recordByStudent[student.userId];
        rows.add(
          _attendanceRow(
            number: '${page.studentOffset + index + 1}',
            studentName: student.displayName,
            status: record == null ? '-' : _statusCode(record.status),
            checkIn: record?.checkInAt == null
                ? ''
                : timeFormat.format(record!.checkInAt!.toLocal()),
            remarks: record?.note ?? '',
          ),
        );
      }
    }

    buffer
      ..write(_attendanceTable(rows))
      ..write(_spacer(80))
      ..write(
        _paragraph(
          'Legend: P - Present   |   L - Late   |   A - Absent   |   '
          'E - Excused   |   - - No record',
          sizeHalfPoints: 16,
        ),
      )
      ..write(_spacer(120))
      ..write(_signatureTable(course.instructorName));
    return buffer.toString();
  }

  String _metadataTable({
    required String courseTitle,
    required String section,
    required String instructor,
    required String courseCode,
    required String attendanceDate,
    required String attendanceWindow,
    required String pageLabel,
    required String generatedAt,
  }) {
    const widths = [1350, 3550, 1350, 3216];
    final rows = [
      ['Course / Subject', courseTitle, 'Attendance Date', attendanceDate],
      ['Program / Section', section, 'Attendance Time', attendanceWindow],
      ['Instructor', instructor, 'Roster Page', pageLabel],
      ['Course Code', courseCode, 'Generated', generatedAt],
    ];
    final rowXml = rows.map((row) {
      return '<w:tr>'
          '${_metadataCell(row[0], widths[0], label: true)}'
          '${_metadataCell(row[1], widths[1])}'
          '${_metadataCell(row[2], widths[2], label: true)}'
          '${_metadataCell(row[3], widths[3])}'
          '</w:tr>';
    }).join();
    return '<w:tbl>'
        '<w:tblPr><w:tblW w:w="9466" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/>'
        '<w:tblCellMar><w:top w:w="30" w:type="dxa"/>'
        '<w:left w:w="50" w:type="dxa"/>'
        '<w:bottom w:w="30" w:type="dxa"/>'
        '<w:right w:w="50" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr>'
        '<w:tblGrid>${widths.map((width) => '<w:gridCol w:w="$width"/>').join()}</w:tblGrid>'
        '$rowXml</w:tbl>';
  }

  String _metadataCell(String text, int width, {bool label = false}) {
    return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:vAlign w:val="center"/></w:tcPr>'
        '${_paragraph(text, sizeHalfPoints: 17, bold: label)}'
        '</w:tc>';
  }

  String _attendanceTable(List<String> rows) {
    const widths = [600, 3000, 1150, 1300, 3416];
    return '<w:tbl>'
        '<w:tblPr><w:tblW w:w="9466" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/>'
        '${_tableBorders()}'
        '<w:tblCellMar><w:top w:w="70" w:type="dxa"/>'
        '<w:left w:w="70" w:type="dxa"/>'
        '<w:bottom w:w="70" w:type="dxa"/>'
        '<w:right w:w="70" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr>'
        '<w:tblGrid>${widths.map((width) => '<w:gridCol w:w="$width"/>').join()}</w:tblGrid>'
        '${_attendanceHeader(widths)}'
        '${rows.join()}'
        '</w:tbl>';
  }

  String _attendanceHeader(List<int> widths) {
    const labels = ['No.', 'Student Name', 'Status', 'Time In', 'Remarks'];
    final cells = <String>[];
    for (var index = 0; index < labels.length; index++) {
      cells.add(
        _tableCell(
          labels[index],
          widths[index],
          bold: true,
          centered: true,
          fill: 'D9E2F3',
        ),
      );
    }
    return '<w:tr><w:trPr><w:tblHeader/><w:cantSplit/>'
        '<w:trHeight w:val="420" w:hRule="atLeast"/></w:trPr>'
        '${cells.join()}</w:tr>';
  }

  String _attendanceRow({
    required String number,
    required String studentName,
    required String status,
    required String checkIn,
    required String remarks,
  }) {
    return '<w:tr><w:trPr><w:cantSplit/>'
        '<w:trHeight w:val="360" w:hRule="atLeast"/></w:trPr>'
        '${_tableCell(number, 600, centered: true)}'
        '${_tableCell(studentName, 3000)}'
        '${_tableCell(status, 1150, centered: true, bold: true)}'
        '${_tableCell(checkIn, 1300, centered: true)}'
        '${_tableCell(remarks, 3416)}'
        '</w:tr>';
  }

  String _tableCell(
    String text,
    int width, {
    bool centered = false,
    bool bold = false,
    String? fill,
  }) {
    return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:vAlign w:val="center"/>'
        '${fill == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>'}'
        '</w:tcPr>'
        '${_paragraph(text, sizeHalfPoints: 18, bold: bold, centered: centered)}'
        '</w:tc>';
  }

  String _signatureTable(String instructorName) {
    final safeName = instructorName.trim().isEmpty
        ? '____________________________'
        : instructorName.trim().toUpperCase();
    return '<w:tbl><w:tblPr><w:tblW w:w="9466" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/></w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="4733"/><w:gridCol w:w="4733"/></w:tblGrid>'
        '<w:tr>'
        '<w:tc><w:tcPr><w:tcW w:w="4733" w:type="dxa"/></w:tcPr>'
        '${_paragraph('Prepared by:', sizeHalfPoints: 17)}'
        '${_spacer(220)}'
        '${_paragraph(safeName, sizeHalfPoints: 18, bold: true, centered: true, underline: true)}'
        '${_paragraph('Course Instructor', sizeHalfPoints: 16, centered: true)}'
        '</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="4733" w:type="dxa"/></w:tcPr>'
        '${_paragraph('Checked by:', sizeHalfPoints: 17)}'
        '${_spacer(220)}'
        '${_paragraph('____________________________', sizeHalfPoints: 18, centered: true)}'
        '${_paragraph('Authorized Personnel', sizeHalfPoints: 16, centered: true)}'
        '</w:tc>'
        '</w:tr></w:tbl>';
  }

  String _paragraph(
    String text, {
    int sizeHalfPoints = 18,
    bool bold = false,
    bool centered = false,
    bool underline = false,
  }) {
    final alignment = centered ? '<w:jc w:val="center"/>' : '';
    final boldXml = bold ? '<w:b/>' : '';
    final underlineXml = underline ? '<w:u w:val="single"/>' : '';
    return '<w:p><w:pPr><w:spacing w:before="0" w:after="0" '
        'w:line="220" w:lineRule="auto"/>$alignment</w:pPr>'
        '<w:r><w:rPr><w:rFonts w:ascii="Arial" w:eastAsia="Arial" '
        'w:hAnsi="Arial" w:cs="Arial"/>$boldXml$underlineXml'
        '<w:sz w:val="$sizeHalfPoints"/><w:szCs w:val="$sizeHalfPoints"/>'
        '</w:rPr><w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>';
  }

  String _spacer(int afterTwips) {
    return '<w:p><w:pPr><w:spacing w:after="$afterTwips"/></w:pPr></w:p>';
  }

  String _headerClearance({required bool pageBreakBefore}) {
    return '<w:p><w:pPr><w:spacing w:before="0" w:after="0" '
        'w:line="2100" w:lineRule="exact"/>'
        '${pageBreakBefore ? '<w:pageBreakBefore/>' : ''}'
        '<w:rPr><w:sz w:val="2"/><w:szCs w:val="2"/></w:rPr></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="2"/><w:szCs w:val="2"/></w:rPr>'
        '<w:t> </w:t></w:r></w:p>';
  }

  String _tableBorders() {
    const border =
        '<w:top w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
        '<w:left w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
        '<w:bottom w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
        '<w:right w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
        '<w:insideH w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
        '<w:insideV w:val="single" w:sz="6" w:space="0" w:color="000000"/>';
    return '<w:tblBorders>$border</w:tblBorders>';
  }

  String _sectionProperties() {
    return '<w:sectPr>'
        '<w:headerReference w:type="even" r:id="rId8"/>'
        '<w:headerReference w:type="default" r:id="rId9"/>'
        '<w:footerReference w:type="even" r:id="rId10"/>'
        '<w:footerReference w:type="default" r:id="rId11"/>'
        '<w:headerReference w:type="first" r:id="rId12"/>'
        '<w:footerReference w:type="first" r:id="rId13"/>'
        '<w:type w:val="continuous"/>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" '
        'w:header="720" w:footer="720" w:gutter="0"/>'
        '<w:pgNumType w:start="1"/><w:cols w:space="720"/>'
        '<w:docGrid w:linePitch="299"/>'
        '</w:sectPr>';
  }

  String _statusCode(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.present => 'P',
      AttendanceStatus.late => 'L',
      AttendanceStatus.absent => 'A',
      AttendanceStatus.excused => 'E',
    };
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}

class _AttendancePage {
  final AttendanceSession? session;
  final List<CourseRosterMember> students;
  final int studentOffset;
  final int partNumber;
  final int partCount;

  const _AttendancePage({
    required this.session,
    required this.students,
    required this.studentOffset,
    required this.partNumber,
    required this.partCount,
  });
}
