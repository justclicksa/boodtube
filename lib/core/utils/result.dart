// ============================================================
// Result<T> - Either<Failure, Success> pattern
// ============================================================
// بديل للـ try-catch المتكرر. كل عملية تُرجع Result<T>.
// الستخدام:
//
//   final result = await getHomeFeed();
//   switch (result) {
//     case Success(:final data):
//       // use data
//     case Failure(:final message, :final type):
//       // handle error
//   }
// ============================================================

import '../errors/exceptions.dart';

sealed class Result<T> {
  const Result();

  /// if-else helper للـ null safety
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, FailureType type, Object? cause) failure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>(:final data) => success(data),
      FailureResult<T>(:final message, :final type, :final cause) =>
        failure(message, type, cause),
    };
  }

  /// map to another type
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(:final data) => Success<R>(transform(data)),
      FailureResult<T>(:final message, :final type, :final cause) =>
        FailureResult<R>(message, type: type, cause: cause),
    };
  }

  /// Get data or null
  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        FailureResult<T>() => null,
      };

  /// Check if success
  bool get isSuccess => this is Success<T>;

  /// Check if failure
  bool get isFailure => this is FailureResult<T>;
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class FailureResult<T> extends Result<T> {
  // FIXED: not @override - these are fields, not getters
  final String message;
  final FailureType type;
  final Object? cause;

  const FailureResult(
    this.message, {
    required this.type,
    this.cause,
  });

  FailureResult.fromException(AppException exception)
      : message = exception.message,
        type = _mapExceptionToFailureType(exception),
        cause = exception.cause;

  static FailureType _mapExceptionToFailureType(AppException exception) {
    return switch (exception) {
      NetworkException _ => FailureType.network,
      NotFoundException _ => FailureType.notFound,
      AuthException _ => FailureType.unauthorized,
      RateLimitException _ => FailureType.rateLimited,
      ParseException _ => FailureType.parse,
      DatabaseException _ => FailureType.database,
      _ => FailureType.unknown,
    };
  }
}
