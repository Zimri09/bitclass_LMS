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
}
