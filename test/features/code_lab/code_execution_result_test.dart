import 'package:bitclass/features/code_lab/data/models/code_execution_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful sandbox result', () {
    final result = CodeExecutionResult.fromMap(const {
      'stdout': 'Hello, Student!\n',
      'stderr': '',
      'exitCode': 0,
      'durationMs': 42,
      'timedOut': false,
      'truncated': false,
    });

    expect(result.succeeded, isTrue);
    expect(result.stdout, 'Hello, Student!\n');
    expect(result.durationMs, 42);
  });

  test('does not treat a timed-out process as successful', () {
    final result = CodeExecutionResult.fromMap(const {
      'stdout': '',
      'stderr': '',
      'exitCode': 0,
      'durationMs': 5000,
      'timedOut': true,
      'truncated': false,
    });

    expect(result.succeeded, isFalse);
  });
}
