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
      .replaceFirst(RegExp(r'^(Exception|Error|FormatException):\s*'), '')
      .trim();
  if (message.isNotEmpty) return message;
  return fallback ?? 'Something went wrong. Please try again.';
}

String uploadErrorMessage(Object error) {
  if (isNetworkFailure(error)) return noInternetConnectionMessage;
  final message = error.toString().toLowerCase();
  if (message.contains('mime') || message.contains('invalidcontenttype')) {
    return 'This file type is not allowed by storage. Check the file extension or ask your administrator to review the allowed file types.';
  }
  if (message.contains('413') ||
      message.contains('entitytoolarge') ||
      message.contains('maximum allowed size')) {
    return 'The file exceeds the storage upload limit. Choose a smaller file.';
  }
  if (message.contains('row-level security') ||
      message.contains('403') ||
      message.contains('unauthorized')) {
    return 'You do not have permission to upload here. Check your course access and sign in again.';
  }
  if (message.contains('bucket') && message.contains('not found')) {
    return 'The upload storage is unavailable. Ask your administrator to check the storage configuration.';
  }
  return 'Upload failed: ${userFriendlyErrorMessage(error)}';
}
