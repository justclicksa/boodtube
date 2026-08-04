// ============================================================
// Tests for DurationFormatter
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:smarttube_poc/core/utils/duration_formatter.dart';

void main() {
  group('DurationFormatter', () {
    group('format', () {
      test('formats minutes:seconds', () {
        expect(DurationFormatter.format(const Duration(minutes: 5, seconds: 30)), '5:30');
      });

      test('formats hours:minutes:seconds', () {
        expect(
          DurationFormatter.format(const Duration(hours: 1, minutes: 23, seconds: 45)),
          '1:23:45',
        );
      });

      test('pads seconds with zero', () {
        expect(DurationFormatter.format(const Duration(minutes: 3, seconds: 5)), '3:05');
      });

      test('handles zero duration', () {
        expect(DurationFormatter.format(Duration.zero), '0:00');
      });

      test('handles long duration (3 hours)', () {
        expect(
          DurationFormatter.format(const Duration(hours: 3, minutes: 15, seconds: 7)),
          '3:15:07',
        );
      });
    });

    group('formatCompact', () {
      test('formats hours only when no minutes', () {
        expect(DurationFormatter.formatCompact(const Duration(hours: 2)), '2h');
      });

      test('formats hours and minutes', () {
        expect(
          DurationFormatter.formatCompact(const Duration(hours: 1, minutes: 30)),
          '1h 30m',
        );
      });

      test('formats minutes only', () {
        expect(DurationFormatter.formatCompact(const Duration(minutes: 45)), '45m');
      });

      test('formats seconds only', () {
        expect(DurationFormatter.formatCompact(const Duration(seconds: 30)), '30s');
      });
    });
  });
}
