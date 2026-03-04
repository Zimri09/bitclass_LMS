import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Custom BlocObserver for debugging and logging
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (kDebugMode)
      log('🟢 onCreate: ${bloc.runtimeType}', name: 'BlocObserver');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      log(
        '🔄 onChange: ${bloc.runtimeType}\n   Current: ${change.currentState}\n   Next: ${change.nextState}',
        name: 'BlocObserver',
      );
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (kDebugMode) {
      log(
        '🔴 onError: ${bloc.runtimeType}\n   Error: $error',
        name: 'BlocObserver',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (kDebugMode) log('⚫ onClose: ${bloc.runtimeType}', name: 'BlocObserver');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode)
      log(
        '📩 onEvent: ${bloc.runtimeType}\n   Event: $event',
        name: 'BlocObserver',
      );
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      log(
        '🔀 onTransition: ${bloc.runtimeType}\n   Event: ${transition.event}\n   Current: ${transition.currentState}\n   Next: ${transition.nextState}',
        name: 'BlocObserver',
      );
    }
  }
}
