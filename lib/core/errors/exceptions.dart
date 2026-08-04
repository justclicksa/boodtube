// ============================================================
// Exceptions & Failures
// ============================================================
// تعريف كل الأخطاء المتوقعة في التطبيق + نوعها.
// نستخدمها في `Result<T>` pattern لتجنّب رمي exceptions عشوائية.
// ============================================================

/// Base exception للـ app
sealed class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Network errors
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// YouTube-specific errors
class YouTubeException extends AppException {
  const YouTubeException(super.message, {super.cause});
}

/// Authentication errors
class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

/// Rate limiting
class RateLimitException extends AppException {
  final Duration retryAfter;
  const RateLimitException(super.message, {required this.retryAfter, super.cause});
}

/// Not found
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

/// Parse / deserialization
class ParseException extends AppException {
  const ParseException(super.message, {super.cause});
}

/// Database / local storage
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

/// Generic / unknown
class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause});
}

/// Failure types (للـ Result pattern)
enum FailureType {
  network,
  notFound,
  unauthorized,
  rateLimited,
  parse,
  database,
  unknown,
}

/// Failure (يستخدم في Result pattern)
class Failure {
  final String message;
  final FailureType type;
  final Object? cause;

  const Failure(this.message, {required this.type, this.cause});

  @override
  String toString() => 'Failure($type): $message';
}
