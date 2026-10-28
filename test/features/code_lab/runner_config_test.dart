import 'package:flutter_test/flutter_test.dart';
// The runner is a standalone Dart service, outside the Flutter package's lib.
// ignore: avoid_relative_lib_imports
import '../../../code_runner/lib/runner_server.dart';

void main() {
  final environment = {
    'RUNNER_SHARED_SECRET': 'test-secret-with-at-least-32-characters',
    'PYTHON_RUNNER_IMAGE': 'python@sha256:${'a' * 64}',
    'C_RUNNER_IMAGE': 'gcc@sha256:${'b' * 64}',
  };
  test('existing Python and C configurations do not require Java', () {
    expect(RunnerConfig.fromEnvironment(environment).javaImage, isNull);
  });
  test('Java images require an immutable digest', () {
    for (final image in ['eclipse-temurin:21-jdk', 'jdk@sha256:invalid']) {
      expect(
        () => RunnerConfig.fromEnvironment({
          ...environment,
          'JAVA_RUNNER_IMAGE': image,
        }),
        throwsStateError,
      );
    }
    final image = 'eclipse-temurin@sha256:${'c' * 64}';
    final config = RunnerConfig.fromEnvironment({
      ...environment,
      'JAVA_RUNNER_IMAGE': image,
    });
    expect(config.javaImage, image);
    expect(config.containerRuntime, 'runsc');
    expect(config.memoryLimitMb, 1024);
  });
}
