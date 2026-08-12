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

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('code-lab-run')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('code-lab-run')));
    await tester.pumpAndSettle();

    expect(repository.lastSource, contains('print'));
    expect(repository.lastStdin, 'Student');
    expect(find.text('Hello, Student!'), findsOneWidget);
    expect(find.textContaining('exit 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      stdout: 'Hello, Student!',
      stderr: '',
      exitCode: 0,
      durationMs: 37,
      timedOut: false,
      truncated: false,
    );
  }
}
