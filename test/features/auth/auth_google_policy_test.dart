import 'dart:convert';

import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BISU Google email policy', () {
    test('accepts the exact BISU domain without case sensitivity', () {
      expect(
        AuthRepository.isAllowedGoogleStudentEmail(' Student@BISU.EDU.PH '),
        isTrue,
      );
    });

    test('rejects personal and lookalike domains', () {
      expect(
        AuthRepository.isAllowedGoogleStudentEmail('student@gmail.com'),
        isFalse,
      );
      expect(
        AuthRepository.isAllowedGoogleStudentEmail('student@fakebisu.edu.ph'),
        isFalse,
      );
      expect(
        AuthRepository.isAllowedGoogleStudentEmail('student@bisu.edu.ph.evil'),
        isFalse,
      );
    });

    test('rejects malformed and missing addresses', () {
      expect(AuthRepository.isAllowedGoogleStudentEmail(null), isFalse);
      expect(
        AuthRepository.isAllowedGoogleStudentEmail('@bisu.edu.ph'),
        isFalse,
      );
      expect(
        AuthRepository.isAllowedGoogleStudentEmail('a@@bisu.edu.ph'),
        isFalse,
      );
    });
  });

  group('Google session detection', () {
    test('allows password login when Google is only a linked identity', () {
      expect(
        AuthRepository.sessionUsesGoogleAuthentication(
          accessToken: _accessTokenWithMethod('password'),
          hasGoogleIdentity: true,
          primaryProvider: 'email',
        ),
        isFalse,
      );
    });

    test('detects an OAuth login for an account with a Google identity', () {
      expect(
        AuthRepository.sessionUsesGoogleAuthentication(
          accessToken: _accessTokenWithMethod('oauth'),
          hasGoogleIdentity: true,
          primaryProvider: 'email',
        ),
        isTrue,
      );
    });

    test('falls back to the primary provider for legacy tokens', () {
      expect(
        AuthRepository.sessionUsesGoogleAuthentication(
          accessToken: 'invalid-token',
          hasGoogleIdentity: true,
          primaryProvider: 'google',
        ),
        isTrue,
      );
    });
  });
}

String _accessTokenWithMethod(String method) {
  String encode(Object value) => base64Url
      .encode(utf8.encode(jsonEncode(value)))
      .replaceAll('=', '');

  final header = encode({'alg': 'none'});
  final payload = encode({
    'amr': [
      {'method': method, 'timestamp': 1},
    ],
  });
  return '$header.$payload.';
}
