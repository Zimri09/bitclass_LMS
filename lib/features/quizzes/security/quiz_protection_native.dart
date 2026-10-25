import 'package:flutter/services.dart';

class QuizProtection {
  static const channel = MethodChannel('bitclass/quiz_protection');
  Future<String> start(void Function(String) onEvent) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'event' && call.arguments is String) {
        onEvent(call.arguments as String);
      }
    });
    try {
      return await channel.invokeMethod<String>('enable') ?? 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return 'unavailable';
    }
  }

  Future<void> stop() async {
    channel.setMethodCallHandler(null);
    try {
      await channel.invokeMethod<void>('disable');
    } on MissingPluginException {
      // Unsupported platforms remain usable.
    } on PlatformException {
      // Cleanup must not prevent navigation.
    }
  }
}
