import 'package:equatable/equatable.dart';

class CodeExecutionResult extends Equatable {
  final String stdout;
  final String stderr;
  final int exitCode;
  final int durationMs;
  final bool timedOut;
  final bool truncated;

  const CodeExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.durationMs,
    required this.timedOut,
    required this.truncated,
  });

  bool get succeeded => exitCode == 0 && !timedOut;

  factory CodeExecutionResult.fromMap(Map<String, dynamic> map) {
    return CodeExecutionResult(
      stdout: map['stdout'] as String? ?? '',
      stderr: map['stderr'] as String? ?? '',
      exitCode: map['exitCode'] as int? ?? -1,
      durationMs: map['durationMs'] as int? ?? 0,
      timedOut: map['timedOut'] as bool? ?? false,
      truncated: map['truncated'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    stdout,
    stderr,
    exitCode,
    durationMs,
    timedOut,
    truncated,
  ];
}
