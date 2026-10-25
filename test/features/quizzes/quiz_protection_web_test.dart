@TestOn('browser')
library;

import 'package:bitclass/features/quizzes/security/quiz_protection_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('browser deters copying and printing and restores listeners', () async {
    final events = <String>[];
    final protection = QuizProtection();
    expect(await protection.start(events.add), 'browser_deterrents');
    final copy = web.Event(
      'copy',
      web.EventInit(bubbles: true, cancelable: true),
    );
    web.document.dispatchEvent(copy);
    expect(copy.defaultPrevented, isTrue);
    expect(events, contains('content_copy_attempt'));
    final printKey = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: 'p', ctrlKey: true, cancelable: true),
    );
    web.window.dispatchEvent(printKey);
    expect(printKey.defaultPrevented, isTrue);
    final input = web.HTMLTextAreaElement();
    web.document.body!.appendChild(input);
    final answerCopy = web.Event(
      'copy',
      web.EventInit(bubbles: true, cancelable: true),
    );
    input.dispatchEvent(answerCopy);
    expect(answerCopy.defaultPrevented, isFalse);
    input.remove();
    await protection.stop();
    final after = web.Event(
      'copy',
      web.EventInit(bubbles: true, cancelable: true),
    );
    web.document.dispatchEvent(after);
    expect(after.defaultPrevented, isFalse);
    final count = events.length;
    web.window.dispatchEvent(web.Event('blur'));
    expect(events.length, count);
  });

  test('blur is recorded only during the quiz', () async {
    final events = <String>[];
    final protection = QuizProtection();
    await protection.start(events.add);
    web.window.dispatchEvent(web.Event('blur'));
    expect(events, ['window_blur']);
    await protection.stop();
  });
}
