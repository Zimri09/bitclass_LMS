import 'package:bitclass/features/quizzes/security/quiz_protection_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = QuizProtection.channel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('native protection enables and disables only on request', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'enable' ? 'android_secure_window' : null;
    });
    final protection = QuizProtection();
    expect(await protection.start((_) {}), 'android_secure_window');
    await protection.stop();
    expect(calls, ['enable', 'disable']);
  });

  test('unsupported native hosts degrade gracefully', () async {
    final protection = QuizProtection();
    expect(await protection.start((_) {}), 'unavailable');
    await protection.stop();
  });

  test('native failures do not interrupt quiz cleanup', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    final protection = QuizProtection();
    expect(await protection.start((_) {}), 'unavailable');
    await protection.stop();
  });
}
