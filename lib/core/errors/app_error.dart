import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

const noInternetConnectionMessage =
    'No internet connection. Please check your network and try again.';

bool isNetworkFailure(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException) {
    return true;
  }

  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => error.error != null && isNetworkFailure(error.error!),
    };
  }

  final message = error.toString().toLowerCase();
  const networkMarkers = [
    'no internet connection',
    'socketexception',
    'clientexception with socketexception',
    'failed host lookup',
    'no address associated with hostname',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection aborted',
    'connection timed out',
    'connection error',
    'connection closed before full header was received',
    'failed to fetch',
    'no route to host',
    'server cannot be reached',
    'timeoutexception',
    'status: timedout',
    'status: timed_out',
    'websocketchannelexception',
    'network request failed',
    'xmlhttprequest error',
    'the internet connection appears to be offline',
    'temporary failure in name resolution',
  ];

  if (networkMarkers.any(message.contains)) return true;

  final unavailableStatus = RegExp(r'\b(502|503|504)\b');
  return unavailableStatus.hasMatch(message) &&
      (message.contains('status') ||
          message.contains('server') ||
          message.contains('service unavailable'));
}

String userFriendlyErrorMessage(Object error, {String? fallback}) {
  if (isNetworkFailure(error)) return noInternetConnectionMessage;

  final message = error
      .toString()
      .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
      .trim();
  if (message.isNotEmpty) return message;
  return fallback ?? 'Something went wrong. Please try again.';
}
