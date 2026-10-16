import 'package:bitclass/features/class_records/data/models/class_record_model.dart';
import 'package:bitclass/features/class_records/data/models/student_performance.dart';
import 'package:bitclass/features/class_records/presentation/widgets/student_performance_dialog.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final course = CourseModel(
    id: 'course',
    title: 'Programming',
    description: '',
    category: 'CS',
    instructorId: 'teacher',
    instructorName: 'Teacher',
    createdAt: DateTime(2026),
  );
  const empty = StudentPerformance(
    student: StudentClassRecord(userId: 'student', displayName: 'Ada Lovelace'),
    quizzes: [],
    activities: [],
    sessionCount: 0,
    attendance: [],
  );

  Future<void> open(
    WidgetTester tester,
    Future<StudentPerformance> Function() load,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStudentPerformanceDialog(
                context,
                course: course,
                load: load,
              ),
              child: const Text('Preview'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows profile and empty states; closes outside and with button',
    (tester) async {
      await open(tester, () async => empty);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('No quizzes in this course.'), findsOneWidget);
      expect(find.text('No activities in this course.'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentPerformanceDialog), findsNothing);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(StudentPerformanceDialog), findsNothing);
    },
  );

  testWidgets('retries a failed load', (tester) async {
    var calls = 0;
    await open(tester, () async {
      if (calls++ == 0) throw Exception('Load failed');
      return empty;
    });
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('many records scroll within a narrow dialog without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(
      tester,
      () async => StudentPerformance(
        student: empty.student,
        quizzes: List.generate(
          30,
          (i) => PerformanceScore('Quiz $i', 38, 40, 'Best graded attempt'),
        ),
        activities: [],
        sessionCount: 0,
        attendance: [],
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Attendance summary'), findsOneWidget);
    expect(find.byTooltip('Close preview').hitTestable(), findsOneWidget);
  });
}
