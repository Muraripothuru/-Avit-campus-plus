/// Typed application errors.
///
/// Never surface raw exception text to the user — screens map [kind] to a
/// friendly message via [AppException.userMessage].
class AppException implements Exception {
  const AppException(
    this.message, {
    this.kind = 'unknown',
    this.statusCode,
    this.fieldErrors = const <String, String>{},
    this.retryable = false,
  });

  /// Developer-facing message (never rendered directly in production).
  final String message;
  final String kind;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final bool retryable;

  static const AppException network = AppException(
    'Unable to reach the AVIT servers',
    kind: 'network',
    retryable: true,
  );
  static const AppException offline = AppException(
    'You appear to be offline',
    kind: 'offline',
    retryable: true,
  );
  static const AppException unauthorized = AppException(
    'Session expired',
    kind: 'auth',
    statusCode: 401,
  );
  static const AppException forbidden = AppException(
    'You do not have permission to perform this action',
    kind: 'forbidden',
    statusCode: 403,
  );
  static const AppException notFound = AppException(
    'The requested resource was not found',
    kind: 'notFound',
    statusCode: 404,
  );
  static const AppException rateLimited = AppException(
    'Too many attempts. Please wait and try again.',
    kind: 'rateLimited',
    statusCode: 429,
  );
  static const AppException server = AppException(
    'Something went wrong on our side',
    kind: 'server',
    statusCode: 500,
    retryable: true,
  );

  String get userMessage => switch (kind) {
    'network' =>
      "You're offline. Some information may be outdated. Check your internet connection.",
    'offline' => "You're offline. Some information may be outdated.",
    'auth' => 'Your session has expired. Please sign in again.',
    'forbidden' => 'You do not have permission to do that.',
    'rateLimited' =>
      'Too many attempts. Please wait a moment and try again.',
    'notFound' => 'We could not find what you were looking for.',
    'validation' => message,
    'locked' => message,
    _ => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'AppException($kind, $statusCode, $message)';
}
