/// Normalizes an instructor-entered web address to an HTTP(S) URL.
///
/// A missing scheme is treated as HTTPS. Other schemes are rejected because
/// course resources must be safe to hand to the platform browser.
Uri normalizeWebUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Please enter a URL.');
  }
  if (RegExp(r'\s').hasMatch(trimmed)) {
    throw const FormatException(
      'Enter a valid web address, such as https://example.com.',
    );
  }

  final enteredUri = Uri.tryParse(trimmed);
  if (enteredUri?.hasScheme ?? false) {
    final scheme = enteredUri!.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const FormatException(
        'Enter a valid web address, such as https://example.com.',
      );
    }
  }

  final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Enter a valid web address, such as https://example.com.',
    );
  }

  return uri.replace(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
  );
}

String? validateWebUrl(String? value, {bool required = true}) {
  final input = value?.trim() ?? '';
  if (input.isEmpty && !required) return null;

  try {
    normalizeWebUrl(input);
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}
