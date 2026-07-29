const int authEmailOtpLength = 8;

String get authEmailOtpInputMessage =>
    'Enter the $authEmailOtpLength-digit verification code.';

String normalizeAuthEmailOtp(String token) {
  final normalized = token.trim();
  final digitsOnly = RegExp(r'^\d+$');
  if (normalized.length != authEmailOtpLength ||
      !digitsOnly.hasMatch(normalized)) {
    throw FormatException(authEmailOtpInputMessage);
  }
  return normalized;
}
