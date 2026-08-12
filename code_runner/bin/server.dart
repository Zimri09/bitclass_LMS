import 'dart:async';
import 'dart:io';

import 'package:bitclass_code_runner/runner_server.dart';

Future<void> main() async {
  final config = RunnerConfig.fromEnvironment(Platform.environment);
  final server = CodeRunnerServer(config);
  await server.start();

  final shutdown = Completer<void>();
  Future<void> stop(ProcessSignal signal) async {
    if (shutdown.isCompleted) return;
    stderr.writeln('Stopping code runner after ${signal.toString()}');
    await server.close();
    shutdown.complete();
  }

  ProcessSignal.sigterm.watch().listen(stop);
  ProcessSignal.sigint.watch().listen(stop);
  await shutdown.future;
}
