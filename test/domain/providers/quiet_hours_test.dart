import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/datasources/dog_settings_api.dart';
import 'package:wimz_app/domain/providers/quiet_hours_provider.dart';

/// Relay `quiet_hours` setting ({enabled, start, end}) and the settings row
/// envelope ({value, version, updated_at, updated_by}).
void main() {
  group('QuietHours', () {
    test('parses the relay value and round-trips', () {
      final q = QuietHours.fromJson({'enabled': true, 'start': '22:00', 'end': '07:00'});
      expect(q.enabled, isTrue);
      expect(q.startTime, const TimeOfDay(hour: 22, minute: 0));
      expect(q.endTime, const TimeOfDay(hour: 7, minute: 0));
      expect(q.toJson(), {'enabled': true, 'start': '22:00', 'end': '07:00'});
    });

    test('tolerates H:MM and seconds, falls back on garbage', () {
      final q = QuietHours.fromJson({'enabled': false, 'start': '9:30:00', 'end': 'nope'});
      expect(q.enabled, isFalse);
      expect(q.start, '09:30');
      expect(q.end, '07:00');
    });

    test('format pads to HH:MM', () {
      expect(QuietHours.format(const TimeOfDay(hour: 6, minute: 5)), '06:05');
    });
  });

  group('DogSettingRow', () {
    test('parses the row envelope', () {
      final row = DogSettingRow.fromJson({
        'value': {'enabled': true, 'start': '21:00', 'end': '06:30'},
        'version': 7,
        'updated_at': '2026-11-07T10:00:00Z',
        'updated_by': 'connector:cl_1',
      }, key: 'quiet_hours');
      expect(row.key, 'quiet_hours');
      expect(row.version, 7);
      expect(row.value['start'], '21:00');
      expect(row.updatedBy, 'connector:cl_1');
      expect(row.updatedAt, isNotNull);
    });
  });
}
