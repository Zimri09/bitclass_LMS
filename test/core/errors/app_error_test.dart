import 'dart:async';
import 'dart:io';

import 'package:bitclass/core/errors/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('network error handling', () {
    test('maps socket, DNS, Realtime, timeout, and unavailable errors', () {
      final errors = <Object>[
        const SocketException('Failed host lookup'),
        'ClientException with SocketException: Failed host lookup: '
            'project.supabase.co',
        'RealtimeSubscribeException(status: channelError, details: '
            'WebSocketChannelException: SocketException: Network is '
            'unreachable)',
        TimeoutException('Request timed out'),
        'AuthRetryableFetchException: Failed to fetch',
        'Server response status: 503 Service Unavailable',
        DioException(
          requestOptions: RequestOptions(path: '/courses'),
          type: DioExceptionType.connectionTimeout,
        ),
      ];

      for (final error in errors) {
        expect(isNetworkFailure(error), isTrue, reason: error.toString());
        expect(userFriendlyErrorMessage(error), noInternetConnectionMessage);
      }
    });

    test('does not replace non-network application errors', () {
      expect(
        userFriendlyErrorMessage(
          Exception('Only instructors can create a course.'),
        ),
        'Only instructors can create a course.',
      );
    });
  });
}
