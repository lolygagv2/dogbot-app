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

  group('treat counter parsing (hard 44-slot carousel)', () {
    test('missing fields yield the unknown sentinel, not -1', () {
      final t = Telemetry.fromApiResponse({'battery': 50});
      expect(t.treatsRemaining, kTreatCountUnknown);
      expect(t.treatsGiven, kTreatCountUnknown);
    });

    test('treats_given and treats_remaining parse; treat_capacity is ignored',
        () {
      final t = Telemetry.fromApiResponse({
        'treats_given': 7,
        'treat_capacity': 20,
        'treats_remaining': 37,
      });
      expect(t.treatsGiven, 7);
      expect(t.treatsRemaining, 37);
      expect(kTreatCapacity, 44,
          reason: 'capacity is a physical constant — 4 wheels × 11 usable '
              'slots — never soft-coded from the robot');
    });

    test('lenient numeric types never drop the frame', () {
      final t = Telemetry.fromApiResponse({
        'treats_remaining': 37.0,
        'treats_given': '7',
      });
      expect(t.treatsRemaining, 37);
      expect(t.treatsGiven, 7);
    });

    test('pre-8e8c91c negative remaining survives parsing (provider clamps)',
        () {
      final t = Telemetry.fromApiResponse({'treats_remaining': -3});
      expect(t.treatsRemaining, -3,
          reason: 'model passes raw value; treatsRemainingProvider clamps to '
              '0 so the UI never renders a negative');
    });

    test('default-constructed telemetry starts unknown', () {
      expect(const Telemetry().treatsRemaining, kTreatCountUnknown);
      expect(const Telemetry().treatsGiven, kTreatCountUnknown);
    });
  });
}
