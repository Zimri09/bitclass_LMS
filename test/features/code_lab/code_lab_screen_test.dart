import 'package:bitclass/features/assignments/presentation/widgets/code_editor.dart';
import 'package:bitclass/features/code_lab/data/models/code_execution_language.dart';
import 'package:bitclass/features/code_lab/data/models/code_execution_result.dart';
import 'package:bitclass/features/code_lab/data/repositories/code_execution_repository.dart';
import 'package:bitclass/features/code_lab/presentation/screens/code_lab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('runs the Python starter program on a phone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeCodeExecutionRepository();
    await tester.pumpWidget(
      RepositoryProvider<CodeExecutionRepository>.value(
        value: repository,
        child: const MaterialApp(home: CodeLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Python & C Sandbox'), findsOneWidget);
    expect(find.text('No network'), findsOneWidget);
    expect(find.byKey(const ValueKey('code-lab-stdin')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-run')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-run')));
    await tester.pumpAndSettle();

    expect(repository.lastSource, contains('print'));
    expect(repository.lastStdin, isEmpty);
    expect(repository.lastLanguage, CodeExecutionLanguage.python);
    expect(find.text('0\n1\n2\n3\n4\n'), findsOneWidget);
    expect(find.textContaining('exit 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends multiline inputs and echoes them in the console', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeCodeExecutionRepository();
    await tester.pumpWidget(
      RepositoryProvider<CodeExecutionRepository>.value(
        value: repository,
        child: const MaterialApp(home: CodeLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-add-input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-add-input')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('code-lab-stdin')),
      'Maria\n20\nManila',
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-run')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-run')));
    await tester.pumpAndSettle();

    expect(repository.lastStdin, 'Maria\n20\nManila');
    expect(find.text('Input supplied'), findsOneWidget);
    expect(find.text('> Maria\n> 20\n> Manila'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('code-lab-stdin')), findsNothing);
    expect(find.byKey(const ValueKey('code-lab-input-echo')), findsNothing);
  });

  testWidgets('shows a safe runner error', (tester) async {
    final repository = _FakeCodeExecutionRepository(
      error: const CodeExecutionException(
        'The secure code runner is unavailable.',
      ),
    );
    await tester.pumpWidget(
      RepositoryProvider<CodeExecutionRepository>.value(
        value: repository,
        child: const MaterialApp(home: CodeLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-run')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-run')));
    await tester.pumpAndSettle();

    expect(find.text('The secure code runner is unavailable.'), findsOneWidget);
  });

  testWidgets('keeps separate Python and C drafts when switching languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeCodeExecutionRepository();
    await tester.pumpWidget(
      RepositoryProvider<CodeExecutionRepository>.value(
        value: repository,
        child: const MaterialApp(home: CodeLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(
      const ValueKey('code-lab-language-selector'),
    );
    await tester.tap(find.descendant(of: selector, matching: find.text('C')));
    await tester.pumpAndSettle();
    expect(find.text('main.c'), findsOneWidget);
    expect(find.text('Run C'), findsOneWidget);

    Finder editorField() => find.descendant(
      of: find.byType(CodeEditor),
      matching: find.byType(TextField),
    );

    const cDraft = '#include <stdio.h>\nint main(void) { puts("C draft"); }';
    await tester.enterText(editorField(), cDraft);
    await tester.tap(
      find.descendant(of: selector, matching: find.text('Python')),
    );
    await tester.pumpAndSettle();
    const pythonDraft = 'print("Python draft")';
    await tester.enterText(editorField(), pythonDraft);

    await tester.tap(find.descendant(of: selector, matching: find.text('C')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(editorField());
    expect(field.controller!.text, cDraft);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-run')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-run')));
    await tester.pumpAndSettle();
    expect(repository.lastLanguage, CodeExecutionLanguage.c);
    expect(repository.lastSource, cDraft);
  });

  testWidgets('labels C compiler diagnostics as a compile error', (
    tester,
  ) async {
    final repository = _FakeCodeExecutionRepository(
      result: const CodeExecutionResult(
        stdout: '',
        stderr: 'main.c:3: error: expected semicolon',
        exitCode: 1,
        durationMs: 22,
        timedOut: false,
        truncated: false,
        phase: CodeExecutionPhase.compile,
      ),
    );
    await tester.pumpWidget(
      RepositoryProvider<CodeExecutionRepository>.value(
        value: repository,
        child: const MaterialApp(home: CodeLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(
      const ValueKey('code-lab-language-selector'),
    );
    await tester.tap(find.descendant(of: selector, matching: find.text('C')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-run')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-run')));
    await tester.pumpAndSettle();

    expect(find.text('Compile error'), findsOneWidget);
    expect(find.textContaining('expected semicolon'), findsOneWidget);
  });
}

class _FakeCodeExecutionRepository implements CodeExecutionRepository {
  final Object? error;
  final CodeExecutionResult? result;
  CodeExecutionLanguage? lastLanguage;
  String? lastSource;
  String? lastStdin;

  _FakeCodeExecutionRepository({this.error, this.result});

  @override
  Future<CodeExecutionResult> execute({
    required CodeExecutionLanguage language,
    required String source,
    required String stdin,
  }) async {
    lastLanguage = language;
    lastSource = source;
    lastStdin = stdin;
    if (error != null) throw error!;
    return result ??
        const CodeExecutionResult(
      stdout: '0\n1\n2\n3\n4\n',
      stderr: '',
      exitCode: 0,
      durationMs: 37,
      timedOut: false,
      truncated: false,
    );
  }
}
