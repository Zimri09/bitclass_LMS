import 'package:bitclass/features/lessons/data/models/models.dart';
import 'package:bitclass/features/lessons/data/repositories/lesson_repository.dart';
import 'package:bitclass/features/lessons/presentation/screens/lesson_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('create lesson form does not expose lesson type choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeLessonRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      RepositoryProvider<LessonRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: LessonEditorScreen(courseId: 'course-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Lesson'), findsOneWidget);
    expect(find.text('Lesson Title'), findsOneWidget);
    expect(find.text('Description (Optional)'), findsOneWidget);
    expect(find.text('Duration (minutes)'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);

    expect(find.text('Lesson Type'), findsNothing);
    expect(find.text('Text/Article'), findsNothing);
    expect(find.text('Video'), findsNothing);
    expect(find.text('Code Tutorial'), findsNothing);
    expect(find.text('Quiz'), findsNothing);
  });

  testWidgets(
    'lesson content stays inside a scrollable editor on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final repository = _FakeLessonRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        RepositoryProvider<LessonRepository>.value(
          value: repository,
          child: const MaterialApp(
            home: LessonEditorScreen(courseId: 'course-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Content'));
      await tester.pumpAndSettle();

      const longWord =
          'https://example.com/a-very-long-path-that-must-wrap-within-the-editor';
      final longContent = List.generate(
        30,
        (index) => '## Paragraph $index\n\n$longWord\nBody text for lesson $index.',
      ).join('\n\n');
      final editor = find.byKey(const Key('lesson-content-field'));

      expect(editor, findsOneWidget);
      await tester.enterText(editor, longContent);
      await tester.pump();

      final textField = tester.widget<TextField>(
        find.descendant(of: editor, matching: find.byType(TextField)),
      );
      final editorRect = tester.getRect(editor);

      expect(textField.controller?.text, longContent);
      expect(textField.expands, isTrue);
      expect(textField.maxLines, isNull);
      expect(textField.textAlignVertical, TextAlignVertical.top);
      expect(textField.keyboardType, TextInputType.multiline);
      expect(editorRect.left, greaterThanOrEqualTo(0));
      expect(editorRect.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeLessonRepository extends LessonRepository {
  final SupabaseClient _client;

  factory _FakeLessonRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeLessonRepository._(client);
  }

  _FakeLessonRepository._(this._client) : super(supabase: _client);

  @override
  Future<List<ModuleModel>> getModules(String courseId) async => const [];

  Future<void> dispose() async => _client.auth.dispose();
}
