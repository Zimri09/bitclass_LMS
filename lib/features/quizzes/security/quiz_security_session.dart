import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../data/repositories/quiz_repository.dart';
import 'quiz_protection.dart';

/// Activity signals are advisory; they never determine grades.
class QuizSecuritySession with WidgetsBindingObserver {
  QuizSecuritySession(this.repository, {QuizProtection? protection})
    : protection = protection ?? QuizProtection();
  final QuizRepository repository;
  final QuizProtection protection;
  String? _attemptId;
  static Future<void> _operations = Future.value();
  final _lastEvents = <String, DateTime>{};
  String capability = 'initializing';

  Future<void> start(String attemptId) {
    _attemptId = attemptId;
    WidgetsBinding.instance.addObserver(this);
    _operations = _operations.then((_) async {
      capability = await protection.start(record);
      if (_attemptId != null) record('protection_$capability');
    });
    return _operations;
  }

  void record(String type) {
    final id = _attemptId;
    if (id == null) return;
    final now = DateTime.now();
    final last = _lastEvents[type];
    if (last != null && now.difference(last).inSeconds < 3) return;
    _lastEvents[type] = now;
    unawaited(
      repository.recordSecurityEvent(
        id,
        type,
        kIsWeb ? 'web' : defaultTargetPlatform.name,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.inactive) record('app_inactive');
    if (state == AppLifecycleState.paused) record('app_background');
  }

  Future<void> stop({bool leaving = false}) {
    if (leaving) record('quiz_left');
    _attemptId = null;
    WidgetsBinding.instance.removeObserver(this);
    _operations = _operations.then((_) => protection.stop());
    return _operations;
  }
}
