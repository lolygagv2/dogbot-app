/// Timestamp helpers for values sent by the relay and robot.
///
/// The backend stores and emits ISO-8601 UTC, but Python's isoformat()
/// usually omits the 'Z' suffix — and Dart's [DateTime.parse] treats a
/// string with no zone designator as *local* time, so UTC wall-clock
/// values were being shown to the user unshifted. These helpers assume
/// naive strings are UTC and return the instant in the device's local
/// timezone.
library;

/// Parse a relay/robot ISO-8601 timestamp into local time.
/// Naive strings (no 'Z' or offset) are treated as UTC.
/// Returns null if [raw] is null, empty, or unparseable.
DateTime? tryParseServerTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final utc = parsed.isUtc
      ? parsed
      : DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
          parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
  return utc.toLocal();
}

/// Like [tryParseServerTimestamp] but never null — falls back to
/// [fallback] (or now) when the string is missing or malformed.
DateTime parseServerTimestamp(String? raw, {DateTime? fallback}) =>
    tryParseServerTimestamp(raw) ?? fallback ?? DateTime.now();
