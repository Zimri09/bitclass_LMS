import 'dart:async';
import 'package:bitclass/features/quizzes/data/repositories/quiz_repository.dart';
import 'package:bitclass/features/quizzes/security/quiz_protection.dart';
import 'package:bitclass/features/quizzes/security/quiz_security_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRepository extends QuizRepository {
  FakeRepository()
    : super(supabase: SupabaseClient('https://example.invalid', 'test'));
  final events = <String>[];
  @override
  Future<void> recordSecurityEvent(
    String id,
    String type,
    String platform,
  ) async {
    events.add('$id:$type');
  }
}

class FakeProtection extends QuizProtection {
  final calls = <String>[];
  Completer<void>? enabling;
  @override
  Future<String> start(void Function(String) onEvent) async {
    calls.add('enable');
    await enabling?.future;
    return 'unavailable';
  }

  @override
  Future<void> stop() async {
    calls.add('disable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'session logs background once and stops logging after leaving',
    () async {
      final repo = FakeRepository();
      final native = FakeProtection();
      final session = QuizSecuritySession(repo, protection: native);
      await session.start('attempt');
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      await session.stop(leaving: true);
      session.record('leave_attempt');
      expect(repo.events, [
        'attempt:protection_unavailable',
        'attempt:app_background',
        'attempt:quiz_left',
      ]);
      expect(native.calls, ['enable', 'disable']);
    },
  );
  test('leaving during enable still clears native protection', () async {
    final repo = FakeRepository();
    final native = FakeProtection()..enabling = Completer<void>();
    final session = QuizSecuritySession(repo, protection: native);
    final start = session.start('attempt');
    await Future<void>.delayed(Duration.zero);
    final stop = session.stop();
    native.enabling!.complete();
    await start;
    await stop;
    expect(native.calls, ['enable', 'disable']);
    expect(repo.events, isEmpty);
  });
}
