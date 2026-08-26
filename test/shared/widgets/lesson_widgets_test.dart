import 'package:bitclass/core/theme/app_colors.dart';
import 'package:bitclass/shared/widgets/lesson_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppColors.isDarkMode = false);
  tearDown(() => AppColors.isDarkMode = true);

  Widget buildSubject(Widget child) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 420, child: child),
        ),
      ),
    );
  }

  testWidgets('module shows lesson count without student progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const ModuleTile(
          title: 'Getting started',
          lessonCount: 3,
          completedCount: 0,
          isExpanded: false,
          showProgress: false,
          lessons: [],
        ),
      ),
    );

    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.text('3 lessons'), findsOneWidget);
    expect(find.textContaining('completed'), findsNothing);
  });

  testWidgets('student module keeps completion progress visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const ModuleTile(
          title: 'Core concepts',
          lessonCount: 2,
          completedCount: 1,
          isExpanded: false,
          lessons: [],
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('1/2 lessons completed'), findsOneWidget);
  });

  testWidgets('lesson tile presents its description and duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const LessonTile(
          title: 'Variables',
          description: 'Learn how values are stored and updated.',
          durationMinutes: 12,
          typeIcon: Icons.code,
        ),
      ),
    );

    expect(
      find.text('Learn how values are stored and updated.'),
      findsOneWidget,
    );
    expect(find.text('12 min'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });
}
