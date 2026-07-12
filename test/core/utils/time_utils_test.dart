import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/core/utils/time_utils.dart';

void main() {
  group('tryParseServerTimestamp', () {
    test('naive string (Python isoformat, no Z) is treated as UTC', () {
      final result = tryParseServerTimestamp('2026-07-12T16:14:00');
      final expected = DateTime.utc(2026, 7, 12, 16, 14).toLocal();
      expect(result, expected);
      expect(result!.isUtc, isFalse); // returned in local time
    });

    test('Z-suffixed string converts to local', () {
      final result = tryParseServerTimestamp('2026-07-12T16:14:00Z');
      expect(result, DateTime.utc(2026, 7, 12, 16, 14).toLocal());
    });

    test('explicit offset string converts to the same instant', () {
      final result = tryParseServerTimestamp('2026-07-12T12:14:00-04:00');
      expect(result, DateTime.utc(2026, 7, 12, 16, 14).toLocal());
    });

    test('naive and Z-suffixed forms of the same instant agree', () {
      expect(
        tryParseServerTimestamp('2026-07-12T16:14:00.123456'),
        tryParseServerTimestamp('2026-07-12T16:14:00.123456Z'),
      );
    });

    test('returns null for null, empty, and garbage', () {
      expect(tryParseServerTimestamp(null), isNull);
      expect(tryParseServerTimestamp(''), isNull);
      expect(tryParseServerTimestamp('not-a-date'), isNull);
    });
  });

  group('parseServerTimestamp', () {
    test('uses fallback when unparseable', () {
      final fallback = DateTime(2020, 1, 1);
      expect(parseServerTimestamp(null, fallback: fallback), fallback);
      expect(parseServerTimestamp('garbage', fallback: fallback), fallback);
    });

    test('falls back to now when no fallback given', () {
      final before = DateTime.now();
      final result = parseServerTimestamp(null);
      final after = DateTime.now();
      expect(result.isBefore(before) || result.isAfter(after), isFalse);
    });
  });
}
