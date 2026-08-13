import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class RunnerConfig {
  final String bindAddress;
  final int port;
  final String sharedSecret;
  final String pythonImage;
  final String dockerBinary;
  final String containerRuntime;
  final int maxConcurrentJobs;
  final int memoryLimitMb;

  const RunnerConfig({
    required this.bindAddress,
    required this.port,
    required this.sharedSecret,
    required this.pythonImage,
    required this.dockerBinary,
    required this.containerRuntime,
    required this.maxConcurrentJobs,
    required this.memoryLimitMb,
  });

  factory RunnerConfig.fromEnvironment(Map<String, String> environment) {
    final secret = environment['RUNNER_SHARED_SECRET']?.trim() ?? '';
    if (secret.length < 32) {
      throw StateError(
        'RUNNER_SHARED_SECRET must contain at least 32 characters.',
      );
    }
    final image = environment['PYTHON_RUNNER_IMAGE']?.trim() ?? '';
    if (!image.contains('@sha256:')) {
      throw StateError(
        'PYTHON_RUNNER_IMAGE must be pinned to a sha256 digest.',
      );
    }
    final port = int.tryParse(environment['RUNNER_PORT'] ?? '') ?? 8080;
    final maxConcurrent =
        int.tryParse(environment['RUNNER_MAX_CONCURRENT'] ?? '') ?? 2;
    final memoryLimitMb =
        int.tryParse(environment['RUNNER_MEMORY_LIMIT_MB'] ?? '') ?? 512;
    final runtime = environment['CONTAINER_RUNTIME']?.trim().isNotEmpty == true
        ? environment['CONTAINER_RUNTIME']!.trim()
        : 'runsc';
    if (port < 1 ||
        port > 65535 ||
        maxConcurrent < 1 ||
        maxConcurrent > 32 ||
        memoryLimitMb < 256 ||
        memoryLimitMb > 1024) {
      throw StateError(
        'Runner port, concurrency, or memory configuration is invalid.',
      );
    }
    if (runtime != 'runsc') {
      throw StateError('CONTAINER_RUNTIME must be runsc.');
    }
    return RunnerConfig(
      bindAddress: environment['RUNNER_BIND_ADDRESS']?.trim().isNotEmpty == true
          ? environment['RUNNER_BIND_ADDRESS']!.trim()
          : '127.0.0.1',
      port: port,
      sharedSecret: secret,
      pythonImage: image,
      dockerBinary: environment['DOCKER_BINARY']?.trim().isNotEmpty == true
          ? environment['DOCKER_BINARY']!.trim()
          : 'docker',
      containerRuntime: runtime,
      maxConcurrentJobs: maxConcurrent,
      memoryLimitMb: memoryLimitMb,
    );
  }
}

class CodeRunnerServer {
  static const int _maxRequestBytes = 32 * 1024;
  static const int _maxSourceBytes = 20 * 1024;
  static const int _maxStdinBytes = 8 * 1024;
  static const int _maxOutputBytesPerStream = 32 * 1024;
  static const int _requestsPerMinute = 10;
  static const Duration _executionTimeout = Duration(seconds: 5);

  final RunnerConfig config;
  final Map<String, List<DateTime>> _recentRequests = {};
  final Random _secureRandom = Random.secure();
  HttpServer? _server;
  int _activeJobs = 0;

  CodeRunnerServer(this.config);

  Future<void> start() async {
    if (!Platform.isLinux) {
      throw UnsupportedError(
        'The code runner must run on a dedicated Linux host.',
      );
    }
    await _verifyHost();
    await _removeStaleContainers();
    _server = await HttpServer.bind(config.bindAddress, config.port);
    _server!.idleTimeout = const Duration(seconds: 15);
    _server!.autoCompress = false;
    stdout.writeln(
      'BitClass code runner listening on ${config.bindAddress}:${config.port}',
    );
    await for (final request in _server!) {
      unawaited(_handle(request));
    }
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    _applyResponseHeaders(request.response);
    if (request.method == 'GET' && request.uri.path == '/healthz') {
      await _json(request.response, HttpStatus.ok, {'status': 'ok'});
      return;
    }
    if (request.method != 'POST' || request.uri.path != '/v1/execute/python') {
      await _json(request.response, HttpStatus.notFound, {
        'error': 'Not found.',
      });
      return;
    }
    if (!_secureEquals(
      request.headers.value('X-Runner-Token') ?? '',
      config.sharedSecret,
    )) {
      await _json(request.response, HttpStatus.unauthorized, {
        'error': 'Unauthorized.',
      });
      return;
    }
    try {
      final body = await _readJsonBody(request);
      final execution = _ExecutionRequest.fromJson(body);
      _validate(execution);
      if (!_allowRequest(execution.userId)) {
        await _json(request.response, HttpStatus.tooManyRequests, {
          'error': 'Too many runs. Wait a minute and try again.',
        });
        return;
      }
      if (_activeJobs >= config.maxConcurrentJobs) {
        await _json(request.response, HttpStatus.serviceUnavailable, {
          'error': 'The code runner is busy. Try again shortly.',
        });
        return;
      }

      _activeJobs++;
      try {
        final result = await _execute(execution);
        await _json(request.response, HttpStatus.ok, result.toJson());
      } finally {
        _activeJobs--;
      }
    } on _RequestError catch (error) {
      await _json(request.response, error.status, {'error': error.message});
    } catch (error) {
      stderr.writeln('Runner request failed: ${error.runtimeType}');
      await _json(request.response, HttpStatus.internalServerError, {
        'error': 'The isolated runner could not start the program.',
      });
    }
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final contentLength = request.contentLength;
    if (contentLength > _maxRequestBytes) {
      throw const _RequestError(
        HttpStatus.requestEntityTooLarge,
        'The execution request is too large.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      if (bytes.length + chunk.length > _maxRequestBytes) {
        throw const _RequestError(
          HttpStatus.requestEntityTooLarge,
          'The execution request is too large.',
        );
      }
      bytes.addAll(chunk);
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map) throw const FormatException();
      return Map<String, dynamic>.from(value);
    } on FormatException {
      throw const _RequestError(
        HttpStatus.badRequest,
        'Invalid execution request.',
      );
    }
  }

  void _validate(_ExecutionRequest request) {
    final userIdPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    if (!userIdPattern.hasMatch(request.userId)) {
      throw const _RequestError(HttpStatus.badRequest, 'Invalid user.');
    }
    if (request.source.trim().isEmpty ||
        utf8.encode(request.source).length > _maxSourceBytes) {
      throw const _RequestError(
        HttpStatus.badRequest,
        'Python source must be between 1 byte and 20 KB.',
      );
    }
    if (utf8.encode(request.stdin).length > _maxStdinBytes) {
      throw const _RequestError(
        HttpStatus.badRequest,
        'Program input must be 8 KB or less.',
      );
    }
    if (request.source.contains('\u0000') || request.stdin.contains('\u0000')) {
      throw const _RequestError(
        HttpStatus.badRequest,
        'The execution request contains invalid text.',
      );
    }
  }

  bool _allowRequest(String userId) {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(minutes: 1));
    final recent = (_recentRequests[userId] ?? [])
        .where((timestamp) => timestamp.isAfter(cutoff))
        .toList(growable: true);
    if (recent.length >= _requestsPerMinute) {
      _recentRequests[userId] = recent;
      return false;
    }
    recent.add(now);
    _recentRequests[userId] = recent;
    if (_recentRequests.length > 10000) {
      _recentRequests.removeWhere(
        (_, timestamps) => timestamps.every((time) => time.isBefore(cutoff)),
      );
    }
    return true;
  }

  Future<_ExecutionResult> _execute(_ExecutionRequest request) async {
    final jobId = _randomId();
    final containerName = 'bitclass-python-$jobId';
    final workspace = await Directory.systemTemp.createTemp('bitclass-code-');
    final sourceFile = File(
      '${workspace.path}${Platform.pathSeparator}main.py',
    );
    final stopwatch = Stopwatch()..start();
    Process? process;
    var timedOut = false;

    try {
      await sourceFile.writeAsString(request.source, flush: true);
      await _setReadOnlyWorkspacePermissions(workspace.path, sourceFile.path);
      process = await Process.start(config.dockerBinary, [
        'run',
        '--name=$containerName',
        '--rm',
        '--pull=never',
        '--label=app=bitclass-code-runner',
        '--init',
        '--runtime=${config.containerRuntime}',
        '--network=none',
        '--read-only',
        '--user=65534:65534',
        '--cap-drop=ALL',
        '--security-opt=no-new-privileges:true',
        '--memory=${config.memoryLimitMb}m',
        '--memory-swap=${config.memoryLimitMb}m',
        '--cpus=0.5',
        '--pids-limit=32',
        '--ulimit=nofile=64:64',
        '--tmpfs=/tmp:rw,noexec,nosuid,nodev,size=16m',
        '--mount=type=bind,src=${workspace.path},dst=/workspace,readonly',
        '--workdir=/workspace',
        '--env=PYTHONDONTWRITEBYTECODE=1',
        config.pythonImage,
        'python3',
        '-I',
        '-S',
        '-B',
        '/workspace/main.py',
      ], mode: ProcessStartMode.normal);

      final stdoutFuture = _collect(process.stdout);
      final stderrFuture = _collect(process.stderr);
      process.stdin.add(utf8.encode(request.stdin));
      await process.stdin.close();

      var exitCode = -1;
      try {
        exitCode = await process.exitCode.timeout(_executionTimeout);
      } on TimeoutException {
        timedOut = true;
        process.kill(ProcessSignal.sigkill);
        exitCode = 124;
      }

      final outputs = await Future.wait([stdoutFuture, stderrFuture]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => const [
          _CollectedOutput('', true),
          _CollectedOutput('', true),
        ],
      );
      stopwatch.stop();
      return _ExecutionResult(
        stdout: outputs[0].text,
        stderr: outputs[1].text,
        exitCode: exitCode,
        durationMs: stopwatch.elapsedMilliseconds,
        timedOut: timedOut,
        truncated: outputs.any((output) => output.truncated),
      );
    } finally {
      process?.kill(ProcessSignal.sigkill);
      await _removeContainer(containerName);
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        stderr.writeln('Could not remove workspace for job $jobId');
      }
    }
  }

  Future<void> _setReadOnlyWorkspacePermissions(
    String directory,
    String sourceFile,
  ) async {
    final directoryResult = await Process.run('chmod', ['0755', directory]);
    final fileResult = await Process.run('chmod', ['0444', sourceFile]);
    if (directoryResult.exitCode != 0 || fileResult.exitCode != 0) {
      throw StateError('Could not secure the execution workspace.');
    }
  }

  Future<void> _verifyHost() async {
    final runtimeResult = await Process.run(config.dockerBinary, [
      'info',
      '--format',
      '{{json .Runtimes}}',
    ]).timeout(const Duration(seconds: 10));
    if (runtimeResult.exitCode != 0 ||
        !runtimeResult.stdout.toString().contains('"runsc"')) {
      throw StateError(
        'Docker is unavailable or the runsc runtime is missing.',
      );
    }

    final imageResult = await Process.run(config.dockerBinary, [
      'image',
      'inspect',
      config.pythonImage,
      '--format',
      '{{.Id}}',
    ]).timeout(const Duration(seconds: 10));
    if (imageResult.exitCode != 0) {
      throw StateError('The pinned Python runner image is not installed.');
    }
  }

  Future<void> _removeStaleContainers() async {
    final result = await Process.run(config.dockerBinary, [
      'ps',
      '--all',
      '--quiet',
      '--filter',
      'label=app=bitclass-code-runner',
    ]).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw StateError('Could not inspect stale runner containers.');
    }
    final containerIds = result.stdout
        .toString()
        .split(RegExp(r'\s+'))
        .where((id) => RegExp(r'^[0-9a-f]{12,64}$').hasMatch(id))
        .toList(growable: false);
    if (containerIds.isEmpty) return;

    final cleanup = await Process.run(config.dockerBinary, [
      'rm',
      '--force',
      ...containerIds,
    ]).timeout(const Duration(seconds: 10));
    if (cleanup.exitCode != 0) {
      throw StateError('Could not remove stale runner containers.');
    }
  }

  Future<void> _removeContainer(String containerName) async {
    try {
      await Process.run(config.dockerBinary, [
        'rm',
        '--force',
        containerName,
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {
      stderr.writeln('Could not confirm container cleanup for $containerName');
    }
  }

  Future<_CollectedOutput> _collect(Stream<List<int>> stream) async {
    final bytes = <int>[];
    var truncated = false;
    await for (final chunk in stream) {
      final remaining = _maxOutputBytesPerStream - bytes.length;
      if (remaining > 0) {
        bytes.addAll(chunk.take(remaining));
      }
      if (chunk.length > remaining) truncated = true;
    }
    return _CollectedOutput(
      utf8.decode(bytes, allowMalformed: true),
      truncated,
    );
  }

  String _randomId() {
    final bytes = List<int>.generate(12, (_) => _secureRandom.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _secureEquals(String provided, String expected) {
    final providedBytes = utf8.encode(provided);
    final expectedBytes = utf8.encode(expected);
    var difference = providedBytes.length ^ expectedBytes.length;
    final length = max(providedBytes.length, expectedBytes.length);
    for (var index = 0; index < length; index++) {
      final left = index < providedBytes.length ? providedBytes[index] : 0;
      final right = index < expectedBytes.length ? expectedBytes[index] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }

  void _applyResponseHeaders(HttpResponse response) {
    response.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff');
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    try {
      response.statusCode = status;
      response.write(jsonEncode(body));
      await response.close();
    } on StateError {
      try {
        await response.close();
      } on StateError {
        // The client disconnected or the response was already completed.
      }
    }
  }
}

class _ExecutionRequest {
  final String userId;
  final String source;
  final String stdin;

  const _ExecutionRequest({
    required this.userId,
    required this.source,
    required this.stdin,
  });

  factory _ExecutionRequest.fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final source = json['source'];
    final stdin = json['stdin'];
    if (userId is! String || source is! String || stdin is! String) {
      throw const _RequestError(
        HttpStatus.badRequest,
        'Invalid execution request.',
      );
    }
    return _ExecutionRequest(userId: userId, source: source, stdin: stdin);
  }
}

class _ExecutionResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final int durationMs;
  final bool timedOut;
  final bool truncated;

  const _ExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.durationMs,
    required this.timedOut,
    required this.truncated,
  });

  Map<String, Object?> toJson() => {
    'stdout': stdout,
    'stderr': stderr,
    'exitCode': exitCode,
    'durationMs': durationMs,
    'timedOut': timedOut,
    'truncated': truncated,
  };
}

class _CollectedOutput {
  final String text;
  final bool truncated;

  const _CollectedOutput(this.text, this.truncated);
}

class _RequestError implements Exception {
  final int status;
  final String message;

  const _RequestError(this.status, this.message);
}
