import 'dart:async';

import 'package:bitclass/core/theme/app_colors.dart';
import 'package:bitclass/features/assignments/data/models/models.dart';
import 'package:bitclass/features/assignments/data/repositories/assignment_repository.dart';
import 'package:bitclass/features/assignments/presentation/screens/assignment_detail_screen.dart';
import 'package:bitclass/features/assignments/presentation/screens/assignment_editor_screen.dart';
import 'package:bitclass/features/assignments/presentation/screens/assignment_list_screen.dart';
import 'package:bitclass/features/assignments/presentation/screens/grade_submission_screen.dart';
import 'package:bitclass/features/assignments/presentation/widgets/code_editor.dart';
import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('instructor can save assignment details and a link as a draft', (
    tester,
  ) async {
    _usePhoneSize(tester);

    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

    final assignmentRepository = _FakeAssignmentRepository();
    addTearDown(assignmentRepository.dispose);
    addTearDown(() async {
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: _assignmentEditorNavigationApp(),
        ),
      ),
    );
    await tester.tap(find.text('Open Assignment Editor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('assignment-title')),
      'Community research activity',
    );
    await tester.enterText(
      find.byKey(const ValueKey('assignment-instructions')),
      'Read the guide and submit your findings.',
    );

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Add link'),
      300,
      scrollable: pageScroll,
    );
    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('assignment-material-link-url')),
      'classroom.google.com/resource',
    );
    await tester.enterText(
      find.byKey(const ValueKey('assignment-material-link-name')),
      'Research guide',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Add link'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('assignment-points')),
      350,
      scrollable: pageScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('assignment-points')),
      '25',
    );
    final criterionName = find.widgetWithText(TextFormField, 'Criteria Name');
    final criterionPercentage = find.widgetWithText(
      TextFormField,
      'Percentage Weight',
    );
    await tester.enterText(criterionName, 'Completion');
    await tester.enterText(criterionPercentage, '100');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave activity editor?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save draft'),
      ),
    );
    await tester.pumpAndSettle();

    final saved = assignmentRepository.createdAssignment;
    expect(find.text('Open Assignment Editor'), findsOneWidget);
    expect(saved, isNotNull);
    expect(saved!.title, 'Community research activity');
    expect(saved.instructions, 'Read the guide and submit your findings.');
    expect(saved.maxPoints, 25);
    expect(saved.gradingCriteria, hasLength(1));
    expect(saved.gradingCriteria.single.name, 'Completion');
    expect(saved.gradingCriteria.single.percentage, 100);
    expect(saved.gradingCriteria.single.id, isNotEmpty);
    expect(saved.isPublished, isFalse);
    expect(saved.requiresAttachment, isTrue);
    expect(saved.language, ProgrammingLanguage.plaintext);
    expect(saved.attachments, hasLength(1));
    expect(saved.attachments.single.name, 'Research guide');
    expect(
      saved.attachments.single.url,
      'https://classroom.google.com/resource',
    );
  });

  testWidgets('editor repairs a missing legacy grading criterion ID', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    final assignmentRepository = _FakeAssignmentRepository(
      assignment: _publishedAssignment(requiresAttachment: false).copyWith(
        gradingCriteria: const [
          GradingCriterion(id: '', name: 'Creativity', percentage: 100),
        ],
      ),
    );
    addTearDown(() async {
      assignmentRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: _assignmentEditorNavigationApp(assignmentId: 'assignment-1'),
        ),
      ),
    );
    await tester.tap(find.text('Open Assignment Editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    final repaired = assignmentRepository.updatedAssignment;
    expect(repaired, isNotNull);
    expect(repaired!.gradingCriteria.single.id, isNotEmpty);
    expect(repaired.gradingCriteria.single.id.length, lessThanOrEqualTo(64));
    expect(find.textContaining('valid ID'), findsNothing);
  });

  testWidgets('student can turn in attached work', (tester) async {
    _usePhoneSize(tester);
    final assignment = _publishedAssignment(requiresAttachment: true);
    final draft = _draftSubmission(
      attachments: const [
        AssignmentAttachment(
          id: 'work-link-1',
          name: 'My research',
          kind: AssignmentAttachmentKind.link,
          url: 'https://example.com/my-research',
        ),
      ],
    );
    final fixture = await _pumpStudentAssignment(
      tester,
      assignment: assignment,
      submission: draft,
    );
    addTearDown(fixture.dispose);

    expect(find.text('Posted: Aug 28, 2026 at 12:18 PM'), findsOneWidget);
    expect(find.text('Assigned'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('turn-in-work')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('turn-in-work')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Turn in your work?')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Turn in'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fixture.assignmentRepository.submitCalls, 1);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.byKey(const ValueKey('unsubmit-work')), findsOneWidget);
  });

  testWidgets('activity editor offers only Python and C', (tester) async {
    _usePhoneSize(tester);
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    final assignmentRepository = _FakeAssignmentRepository();
    addTearDown(() async {
      assignmentRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: _assignmentEditorNavigationApp(),
        ),
      ),
    );
    await tester.tap(find.text('Open Assignment Editor'));
    await tester.pumpAndSettle();

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Advanced code activity'),
      350,
      scrollable: pageScroll,
    );
    await tester.tap(find.text('Advanced code activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable code editor'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('activity-starter-code-editor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-reference-code-editor')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('activity-language-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Python'), findsWidgets);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('Dart'), findsNothing);
    expect(find.text('JavaScript'), findsNothing);
    expect(find.text('C++'), findsNothing);
  });

  testWidgets('instructor code editors are dark and preserve exact content', (
    tester,
  ) async {
    _usePhoneSize(tester);
    const originalStarter = '  #include <stdio.h>\n\n';
    const originalSolution = 'int main(void) {\n    return 0;\n}\n';
    const updatedStarter = '  int value = 1;\n\n';
    const updatedSolution = 'int main(void) {\n    printf("%d", value);\n}\n';
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    final assignmentRepository = _FakeAssignmentRepository(
      assignment: _publishedAssignment(
        requiresAttachment: false,
        language: ProgrammingLanguage.c,
      ).copyWith(starterCode: originalStarter, solutionCode: originalSolution),
    );
    addTearDown(() async {
      assignmentRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: _assignmentEditorNavigationApp(assignmentId: 'assignment-1'),
        ),
      ),
    );
    await tester.tap(find.text('Open Assignment Editor'));
    await tester.pumpAndSettle();

    final starter = find.byKey(const ValueKey('activity-starter-code-editor'));
    final reference = find.byKey(
      const ValueKey('activity-reference-code-editor'),
    );
    expect(starter, findsOneWidget);
    expect(reference, findsOneWidget);
    _expectTerminalBackground(tester, starter);
    _expectTerminalBackground(tester, reference);
    expect(_editorText(tester, starter), originalStarter);
    expect(_editorText(tester, reference), originalSolution);

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(starter, 350, scrollable: pageScroll);
    await tester.enterText(
      find.descendant(of: starter, matching: find.byType(EditableText)),
      updatedStarter,
    );
    await tester.scrollUntilVisible(reference, 350, scrollable: pageScroll);
    await tester.enterText(
      find.descendant(of: reference, matching: find.byType(EditableText)),
      updatedSolution,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(assignmentRepository.updatedAssignment?.starterCode, updatedStarter);
    expect(
      assignmentRepository.updatedAssignment?.solutionCode,
      updatedSolution,
    );
  });

  testWidgets('student submits exact code and selected language', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final fixture = await _pumpStudentAssignment(
      tester,
      assignment: _publishedAssignment(
        requiresAttachment: false,
        language: ProgrammingLanguage.python,
      ),
    );
    addTearDown(fixture.dispose);
    const exactCode =
        'def greet(name):\n'
        '    print("Hello, " + name)\n'
        '\n'
        "greet('Student')";

    await tester.scrollUntilVisible(
      find.byType(CodeEditor),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final editor = find.descendant(
      of: find.byType(CodeEditor),
      matching: find.byType(EditableText),
    );
    await tester.enterText(editor, exactCode);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('turn-in-work')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('turn-in-work')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Turn in'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fixture.assignmentRepository.submittedCode, exactCode);
    expect(
      fixture.assignmentRepository.submission?.language,
      ProgrammingLanguage.python,
    );
  });

  testWidgets('instructor code viewer loads exact saved code', (tester) async {
    _usePhoneSize(tester);
    const exactCode = 'if (ready) {\n    printf("Hello");\n}\n';
    final assignment = _publishedAssignment(
      requiresAttachment: false,
      language: ProgrammingLanguage.c,
    );
    final submission = _draftSubmission().copyWith(
      code: exactCode,
      language: ProgrammingLanguage.c,
      status: SubmissionStatus.submitted,
      submittedAt: DateTime.utc(2026, 8, 28, 4, 28),
    );
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    final assignmentRepository = _FakeAssignmentRepository(
      assignment: assignment,
      submission: submission,
    );
    addTearDown(() async {
      assignmentRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: GradeSubmissionScreen(
              courseId: 'course-1',
              assignmentId: 'assignment-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_student.displayNameOrEmail));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Submitted Code'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    final codeViewer = find.byKey(
      const ValueKey('submitted-code-submission-1'),
    );
    expect(codeViewer, findsOneWidget);
    final editable = tester.widget<EditableText>(
      find.descendant(of: codeViewer, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, exactCode);
    expect(editable.readOnly, isTrue);
  });

  testWidgets('instructor sees the original activity posted time', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_instructor));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    final assignmentRepository = _FakeAssignmentRepository(
      assignment: _publishedAssignment(requiresAttachment: false),
    );

    addTearDown(() async {
      assignmentRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: AssignmentDetailScreen(
              courseId: 'course-1',
              assignmentId: 'assignment-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Posted: Aug 28, 2026 at 12:18 PM'), findsOneWidget);
  });

  testWidgets('activity card stays aligned at phone width', (tester) async {
    _usePhoneSize(tester);
    final authRepository = _FakeAuthRepository();
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthUserUpdated(_admin));
    await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
    final assignmentRepository = _FakeAssignmentRepository(
      assignment: _publishedAssignment(requiresAttachment: false),
    );

    addTearDown(() async {
      assignmentRepository.dispose();
      await authBloc.close();
      await authRepository.dispose();
    });

    await tester.pumpWidget(
      RepositoryProvider<AssignmentRepository>.value(
        value: assignmentRepository,
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: Scaffold(
              body: AssignmentListScreen(courseId: 'course-1', embedded: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final posted = find.text('Posted: Aug 28, 2026 at 12:18 PM');
    expect(posted, findsOneWidget);
    expect(find.byTooltip('Activity actions'), findsOneWidget);
    expect(tester.getSize(posted).height, lessThanOrEqualTo(36));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'student can mark an activity done and unsubmit before due date',
    (tester) async {
      _usePhoneSize(tester);
      final fixture = await _pumpStudentAssignment(
        tester,
        assignment: _publishedAssignment(requiresAttachment: false),
      );
      addTearDown(fixture.dispose);

      expect(find.text('Assigned'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mark-work-done')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('mark-work-done')));
      await tester.pumpAndSettle();

      var dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Mark this activity as done?'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, 'Mark as done'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fixture.assignmentRepository.markDoneCalls, 1);
      expect(find.text('Done'), findsWidgets);
      expect(find.byKey(const ValueKey('unsubmit-work')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('unsubmit-work')));
      await tester.pumpAndSettle();
      dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Unsubmit this work?')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, 'Unsubmit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fixture.assignmentRepository.unsubmitCalls, 1);
      expect(find.text('Assigned'), findsWidgets);
      expect(find.byKey(const ValueKey('mark-work-done')), findsOneWidget);
    },
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectTerminalBackground(WidgetTester tester, Finder editor) {
  final hasTerminalBackground = tester
      .widgetList<Container>(
        find.descendant(of: editor, matching: find.byType(Container)),
      )
      .any(
        (container) =>
            (container.decoration as BoxDecoration?)?.color ==
            AppColors.codeBackground,
      );
  expect(hasTerminalBackground, isTrue);
}

String _editorText(WidgetTester tester, Finder editor) {
  return tester
      .widget<EditableText>(
        find.descendant(of: editor, matching: find.byType(EditableText)),
      )
      .controller
      .text;
}

Future<_StudentFixture> _pumpStudentAssignment(
  WidgetTester tester, {
  required AssignmentModel assignment,
  SubmissionModel? submission,
}) async {
  final authRepository = _FakeAuthRepository();
  final authBloc = AuthBloc(authRepository: authRepository)
    ..add(AuthUserUpdated(_student));
  await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);

  final assignmentRepository = _FakeAssignmentRepository(
    assignment: assignment,
    submission: submission,
  );
  await tester.pumpWidget(
    RepositoryProvider<AssignmentRepository>.value(
      value: assignmentRepository,
      child: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const MaterialApp(
          home: AssignmentDetailScreen(
            courseId: 'course-1',
            assignmentId: 'assignment-1',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _StudentFixture(
    authRepository: authRepository,
    authBloc: authBloc,
    assignmentRepository: assignmentRepository,
  );
}

Widget _assignmentEditorNavigationApp({String? assignmentId}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AssignmentEditorScreen(
                  courseId: 'course-1',
                  assignmentId: assignmentId,
                ),
              ),
            ),
            child: const Text('Open Assignment Editor'),
          ),
        ),
      ),
    ),
  );
}

AssignmentModel _publishedAssignment({
  required bool requiresAttachment,
  ProgrammingLanguage language = ProgrammingLanguage.plaintext,
}) {
  return AssignmentModel(
    id: 'assignment-1',
    courseId: 'course-1',
    title: 'Community research activity',
    description: 'Read the guide and complete the activity.',
    instructions: 'Read the guide and complete the activity.',
    language: language,
    requiresAttachment: requiresAttachment,
    maxPoints: 25,
    dueDate: DateTime.now().add(const Duration(days: 2)),
    isPublished: true,
    createdAt: DateTime(2026, 8, 28, 12, 18),
  );
}

SubmissionModel _draftSubmission({
  List<AssignmentAttachment> attachments = const [],
}) {
  return SubmissionModel(
    id: 'submission-1',
    assignmentId: 'assignment-1',
    courseId: 'course-1',
    userId: _student.id,
    userDisplayName: _student.displayNameOrEmail,
    code: '',
    attachments: attachments,
    createdAt: DateTime.utc(2026, 8, 13),
  );
}

final _instructor = UserModel(
  id: 'instructor-1',
  email: 'instructor@example.com',
  firstName: 'Instructor',
  lastName: 'Teacher',
  role: 'instructor',
  createdAt: DateTime.utc(2026, 8, 13),
);

final _admin = UserModel(
  id: 'admin-1',
  email: 'admin@example.com',
  firstName: 'Admin',
  lastName: 'User',
  role: 'admin',
  createdAt: DateTime.utc(2026, 8, 13),
);

final _student = UserModel(
  id: 'student-1',
  email: 'student@example.com',
  firstName: 'Student',
  lastName: 'Learner',
  role: 'student',
  createdAt: DateTime.utc(2026, 8, 13),
);

class _StudentFixture {
  final _FakeAuthRepository authRepository;
  final AuthBloc authBloc;
  final _FakeAssignmentRepository assignmentRepository;

  const _StudentFixture({
    required this.authRepository,
    required this.authBloc,
    required this.assignmentRepository,
  });

  Future<void> dispose() async {
    await authBloc.close();
    await authRepository.dispose();
    assignmentRepository.dispose();
  }
}

class _FakeAssignmentRepository extends AssignmentRepository {
  final SupabaseClient _client;
  AssignmentModel? assignment;
  SubmissionModel? submission;
  AssignmentModel? createdAssignment;
  AssignmentModel? updatedAssignment;
  int submitCalls = 0;
  String? submittedCode;
  int markDoneCalls = 0;
  int unsubmitCalls = 0;

  factory _FakeAssignmentRepository({
    AssignmentModel? assignment,
    SubmissionModel? submission,
  }) {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeAssignmentRepository._(
      client,
      assignment: assignment,
      submission: submission,
    );
  }

  _FakeAssignmentRepository._(this._client, {this.assignment, this.submission})
    : super(supabase: _client);

  @override
  Future<AssignmentModel?> getAssignment(String assignmentId) async =>
      assignment;

  @override
  Future<List<AssignmentModel>> getAssignmentsForCourse(
    String courseId, {
    bool includeDrafts = false,
  }) async => assignment == null ? const [] : [assignment!];

  @override
  Future<List<SubmissionModel>> getAssignmentSubmissions(
    String assignmentId,
  ) async => submission == null ? const [] : [submission!];

  @override
  Future<SubmissionModel?> getUserSubmission(
    String assignmentId,
    String userId,
  ) async => submission;

  @override
  Future<AssignmentModel> createAssignment(AssignmentModel value) async {
    assignment = value;
    createdAssignment = value;
    return value;
  }

  @override
  Future<AssignmentModel> updateAssignment(AssignmentModel value) async {
    assignment = value;
    updatedAssignment = value;
    return value;
  }

  @override
  Future<SubmissionModel> submitAssignment({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    required String code,
    List<AssignmentAttachment>? attachments,
  }) async {
    submitCalls++;
    submittedCode = code;
    submission = _completedSubmission(
      status: SubmissionStatus.submitted,
      userDisplayName: userDisplayName,
      code: code,
      attachments: attachments,
    );
    return submission!;
  }

  @override
  Future<SubmissionModel> markAsDone({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    String code = '',
    List<AssignmentAttachment>? attachments,
  }) async {
    markDoneCalls++;
    submission = _completedSubmission(
      status: SubmissionStatus.done,
      userDisplayName: userDisplayName,
      code: code,
      attachments: attachments,
    );
    return submission!;
  }

  @override
  Future<SubmissionModel> unsubmitAssignment({
    required String assignmentId,
    required String userId,
  }) async {
    unsubmitCalls++;
    submission = submission!.copyWith(
      status: SubmissionStatus.draft,
      isLate: false,
      updatedAt: DateTime.now(),
      clearSubmittedAt: true,
    );
    return submission!;
  }

  SubmissionModel _completedSubmission({
    required SubmissionStatus status,
    required String userDisplayName,
    required String code,
    List<AssignmentAttachment>? attachments,
  }) {
    final now = DateTime.now();
    return SubmissionModel(
      id: submission?.id ?? 'submission-1',
      assignmentId: assignment!.id,
      courseId: assignment!.courseId,
      userId: _student.id,
      userDisplayName: userDisplayName,
      code: code,
      language: assignment!.language,
      attachments: attachments ?? submission?.attachments ?? const [],
      status: status,
      createdAt: submission?.createdAt ?? now,
      updatedAt: now,
      submittedAt: now,
    );
  }

  void dispose() => _client.auth.dispose();
}

class _FakeAuthRepository extends AuthRepository {
  final SupabaseClient _client;
  final StreamController<User?> _authController =
      StreamController<User?>.broadcast();

  factory _FakeAuthRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeAuthRepository._(client);
  }

  _FakeAuthRepository._(this._client) : super(supabase: _client);

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  Future<void> dispose() async {
    _client.auth.dispose();
    await _authController.close();
  }
}
