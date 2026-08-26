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

    expect(find.text('Python Sandbox'), findsOneWidget);
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
}

class _FakeCodeExecutionRepository implements CodeExecutionRepository {
  final Object? error;
  String? lastSource;
  String? lastStdin;

  _FakeCodeExecutionRepository({this.error});

  @override
  Future<CodeExecutionResult> executePython({
    required String source,
    required String stdin,
  }) async {
    lastSource = source;
    lastStdin = stdin;
    if (error != null) throw error!;
    return const CodeExecutionResult(
      stdout: '0\n1\n2\n3\n4\n',
      stderr: '',
      exitCode: 0,
      durationMs: 37,
      timedOut: false,
      truncated: false,
    );
  }
}
