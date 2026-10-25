import 'package:bitclass/features/quizzes/security/quiz_protection_web.dart';
import 'package:web/web.dart' as web;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  try {
    final events = <String>[];
    final protection = QuizProtection();
    await protection.start(events.add);
    final copy = web.Event(
      'copy',
      web.EventInit(bubbles: true, cancelable: true),
    );
    web.document.dispatchEvent(copy);
    check(copy.defaultPrevented, 'copy should be prevented');
    final input = web.HTMLTextAreaElement();
    web.document.body!.appendChild(input);
    final edit = web.Event(
      'copy',
      web.EventInit(bubbles: true, cancelable: true),
    );
    input.dispatchEvent(edit);
    check(!edit.defaultPrevented, 'answer editing must work');
    input.remove();
    final print = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: 'p', ctrlKey: true, cancelable: true),
    );
    web.window.dispatchEvent(print);
    check(print.defaultPrevented, 'print shortcut should be prevented');
    web.window.dispatchEvent(web.Event('blur'));
    check(events.contains('window_blur'), 'blur should be logged');
    await protection.stop();
    final count = events.length;
    final restored = web.Event('copy', web.EventInit(cancelable: true));
    web.document.dispatchEvent(restored);
    web.window.dispatchEvent(web.Event('blur'));
    check(
      !restored.defaultPrevented && events.length == count,
      'listeners must be removed',
    );
    web.document.body!.textContent =
        'PASS: browser copy, input editing, printing, blur and cleanup';
  } catch (error) {
    web.document.body!.textContent = 'FAIL: $error';
  }
}
