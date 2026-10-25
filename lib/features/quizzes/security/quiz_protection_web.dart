import 'dart:js_interop';
import 'package:web/web.dart' as web;

class QuizProtection {
  final _listeners = <(web.EventTarget, String, JSFunction)>[];
  web.HTMLStyleElement? _style;

  void _listen(
    web.EventTarget target,
    String type,
    void Function(web.Event) fn,
  ) {
    final listener = fn.toJS;
    target.addEventListener(type, listener, true.toJS);
    _listeners.add((target, type, listener));
  }

  Future<String> start(void Function(String) onEvent) async {
    await stop();
    for (final type in ['copy', 'cut', 'contextmenu', 'dragstart']) {
      _listen(web.document, type, (event) {
        final target = event.target;
        // Preserve editing within answer fields.
        if (target != null &&
            target.isA<web.Element>() &&
            (target as web.Element).closest(
                  'input, textarea, [contenteditable="true"]',
                ) !=
                null) {
          return;
        }
        event.preventDefault();
        onEvent('content_copy_attempt');
      });
    }
    _listen(web.window, 'keydown', (event) {
      final key = event as web.KeyboardEvent;
      if ((key.ctrlKey || key.metaKey) && key.key.toLowerCase() == 'p') {
        event.preventDefault();
        onEvent('print_attempt');
      }
    });
    _listen(web.window, 'beforeprint', (_) => onEvent('print_attempt'));
    _listen(web.document, 'visibilitychange', (_) {
      if (web.document.hidden) onEvent('tab_hidden');
    });
    _listen(web.window, 'blur', (_) => onEvent('window_blur'));
    _listen(web.window, 'beforeunload', (event) {
      onEvent('leave_attempt');
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    });
    _style = web.HTMLStyleElement()
      ..textContent =
          '@media print { body { visibility: hidden !important; } }';
    web.document.head?.appendChild(_style!);
    return 'browser_deterrents';
  }

  Future<void> stop() async {
    for (final (target, type, listener) in _listeners) {
      target.removeEventListener(type, listener, true.toJS);
    }
    _listeners.clear();
    _style?.remove();
    _style = null;
  }
}
