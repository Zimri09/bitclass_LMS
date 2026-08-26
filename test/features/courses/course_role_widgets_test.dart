import 'package:bitclass/core/theme/app_colors.dart';
import 'package:bitclass/features/courses/presentation/widgets/instructor/instructor_content_actions.dart';
import 'package:bitclass/features/courses/presentation/widgets/shared/course_resource_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppColors.isDarkMode = false);
  tearDown(() => AppColors.isDarkMode = false);

  Widget buildSubject(Widget child, {double width = 500}) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  testWidgets('shared course resources expose materials and classwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        CourseResourceLinks(courseId: 'course-1', onOpenClasswork: () {}),
      ),
    );

    expect(find.text('Learning materials'), findsOneWidget);
    expect(find.text('Assignments & activities'), findsOneWidget);
  });

  testWidgets('instructor actions contain all content creation choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        InstructorContentActions(courseId: 'course-1', onContentChanged: () {}),
      ),
    );

    expect(find.text('Add Lesson'), findsOneWidget);
    expect(find.text('Add Quiz'), findsOneWidget);
    expect(find.text('Add Assignment'), findsOneWidget);
    expect(find.text('Course materials'), findsOneWidget);
  });
}
