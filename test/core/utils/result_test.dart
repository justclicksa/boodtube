// ============================================================
// Unit tests for Result<T> pattern
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/core/utils/result.dart';
import 'package:smarttube_poc/core/errors/exceptions.dart';

void main() {
  group('Result', () {
    test('Success is created with data', () {
      const result = Success<int>(42);
      expect(result, isA<Success<int>>());
      expect(result.dataOrNull, 42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('FailureResult is created with message and type', () {
      const result = FailureResult<int>('Oops', type: FailureType.network);
      expect(result, isA<FailureResult<int>>());
      expect(result.dataOrNull, isNull);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('when() pattern matching works', () {
      const success = Success<String>('hello');
      String result = success.when(
        success: (data) => 'success: $data',
        failure: (msg, type, cause) => 'failure: $msg',
      );
      expect(result, 'success: hello');

      const failure = FailureResult<String>('error', type: FailureType.network);
      result = failure.when(
        success: (data) => 'success: $data',
        failure: (msg, type, cause) => 'failure: $msg',
      );
      expect(result, 'failure: error');
    });

    test('map() transforms success data', () {
      const success = Success<int>(10);
      final mapped = success.map((x) => x * 2);
      expect(mapped.dataOrNull, 20);
    });

    test('map() preserves failure', () {
      const failure = FailureResult<int>('oops', type: FailureType.network);
      final mapped = failure.map((x) => x * 2);
      expect(mapped.isFailure, isTrue);
    });

    test('FailureResult.fromException maps exception to failure type', () {
      final failure = FailureResult<int>.fromException(
        const NetworkException('No connection'),
      );
      expect(failure.type, FailureType.network);

      final failure2 = FailureResult<int>.fromException(
        const NotFoundException('Not found'),
      );
      expect(failure2.type, FailureType.notFound);

      final failure3 = FailureResult<int>.fromException(
        const ParseException('Bad JSON'),
      );
      expect(failure3.type, FailureType.parse);
    });
  });
}
