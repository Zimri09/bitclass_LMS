import 'package:bitclass/features/courses/data/models/course_model.dart';
import 'package:bitclass/features/courses/data/repositories/course_repository.dart';
import 'package:bitclass/shared/widgets/classroom_course_card.dart';
import 'package:bitclass/shared/widgets/course_banner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('course layout selects the platform-appropriate sliver', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverClassroomCourseLayout(
              itemCount: 2,
              itemBuilder: (context, index) => Text('Course $index'),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(kIsWeb ? SliverGrid : SliverList), findsOneWidget);
    expect(find.text('Course 0'), findsOneWidget);
  });

  testWidgets('compact classroom card fits a desktop grid tile', (tester) async {
    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeCourseRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      RepositoryProvider<CourseRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 314,
                child: ClassroomCourseCard(
                  course: _course,
                  compact: true,
                  statusLabel: 'Published',
                  onTap: () {},
                  trailing: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                  footer: const [
                    Icon(Icons.people_outline),
                    SizedBox(width: 4),
                    Text('24'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Algorithms 101'), findsOneWidget);
    expect(find.text('BSCS 3A'), findsOneWidget);
    expect(find.text('Instructor Teacher'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);

    final banner = tester.widget<CourseBannerWidget>(
      find.byType(CourseBannerWidget),
    );
    expect(banner.height, 112);
    expect(tester.takeException(), isNull);
  });
}

final _course = CourseModel(
  id: 'course-1',
  title: 'Algorithms 101',
  description: 'BSCS 3A',
  category: 'Algorithms',
  instructorId: 'instructor-1',
  instructorName: 'Instructor Teacher',
  thumbnailUrl: 'preset:blue-teal',
  isPublished: true,
  enrollmentCount: 24,
  lessonCount: 8,
  createdAt: DateTime.utc(2026, 8, 27),
);

class _FakeCourseRepository extends CourseRepository {
  final SupabaseClient _client;

  factory _FakeCourseRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeCourseRepository._(client);
  }

  _FakeCourseRepository._(this._client) : super(supabase: _client);

  @override
  Stream<CourseModel?> watchCourse(String courseId) => Stream.value(_course);

  void dispose() {
    _client.auth.dispose();
  }
}
