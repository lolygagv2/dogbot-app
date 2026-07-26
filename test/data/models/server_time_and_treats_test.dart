import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/mission.dart';
import 'package:wimz_app/data/models/telemetry.dart';

void main() {
  group('MissionHistoryEntry timestamps render device-local', () {
    test('Z-suffixed UTC string parses to the correct local instant', () {
      final entry = MissionHistoryEntry.fromJson({
        'id': 'h1',
        'missionId': 'm1',
        'missionName': 'Sit Training',
        'dogId': 'dog-a',
        'startedAt': '2026-07-25T14:30:00Z',
        'completedAt': '2026-07-25T14:45:00Z',
      });

      final expected = DateTime.utc(2026, 7, 25, 14, 30).toLocal();
      expect(entry.startedAt, expected);
      expect(entry.startedAt.isUtc, isFalse,
          reason: 'UTC DateTime would render server wall-clock in DateFormat');
      expect(entry.completedAt, DateTime.utc(2026, 7, 25, 14, 45).toLocal());
    });

    test('naive (no-Z) string is treated as UTC per relay contract', () {
      final entry = MissionHistoryEntry.fromJson({
        'id': 'h2',
        'missionId': 'm1',
        'missionName': 'Sit Training',
        'dogId': 'dog-a',
        'startedAt': '2026-07-25T14:30:00',
      });
      expect(entry.startedAt, DateTime.utc(2026, 7, 25, 14, 30).toLocal());
      expect(entry.completedAt, isNull);
    });
  });

  group('treats_remaining negative handling', () {
    test('missing field yields the unknown sentinel, not -1', () {
      final t = Telemetry.fromApiResponse({'battery': 50});
      expect(t.treatsRemaining, kTreatCountUnknown);
    });

    test('genuine negative count survives parsing', () {
      final t = Telemetry.fromApiResponse({'treats_remaining': -3});
      expect(t.treatsRemaining, -3);
    });

    test('default-constructed telemetry starts unknown', () {
      expect(const Telemetry().treatsRemaining, kTreatCountUnknown);
    });
  });
}
