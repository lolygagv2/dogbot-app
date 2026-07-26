import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/activity_aggregation.dart';
import 'package:wimz_app/data/models/notification_event.dart';

NotificationEvent _event(
  NotificationEventType type, {
  String? dogId,
  DateTime? at,
  String id = '',
}) {
  return NotificationEvent(
    id: id.isEmpty ? '${type.name}-${dogId ?? 'untagged'}-${at?.millisecondsSinceEpoch ?? 0}' : id,
    type: type,
    timestamp: at ?? DateTime(2026, 7, 25, 12),
    title: type.name,
    dogId: dogId,
  );
}

void main() {
  final day = DateTime(2026, 7, 25, 12);

  group('summarizeDay per-dog filtering', () {
    final events = [
      _event(NotificationEventType.bark, dogId: 'dog-a', at: day, id: 'b1'),
      _event(NotificationEventType.bark, dogId: null, at: day, id: 'b2'),
      _event(NotificationEventType.treatDispensed, dogId: null, at: day, id: 't1'),
      _event(NotificationEventType.treatDispensed, dogId: 'dog-b', at: day, id: 't2'),
      _event(NotificationEventType.alert, dogId: null, at: day, id: 'a1'),
    ];

    test('strict (C4 default) excludes untagged events', () {
      final s = summarizeDay(events, dogId: 'dog-a', day: day);
      expect(s.barkCount, 1);
      expect(s.treatCount, 0);
      expect(s.alertCount, 0);
    });

    test('includeUntagged counts untagged rows (relay history has no dog_id)',
        () {
      final s =
          summarizeDay(events, dogId: 'dog-a', day: day, includeUntagged: true);
      expect(s.barkCount, 2); // dog-a + untagged
      expect(s.treatCount, 1); // untagged only — dog-b still excluded
      expect(s.alertCount, 1); // untagged guardian alert now visible
    });

    test('empty dogId aggregates everything', () {
      final s = summarizeDay(events, dogId: '', day: day);
      expect(s.barkCount, 2);
      expect(s.treatCount, 2);
      expect(s.alertCount, 1);
    });
  });

  group('guardian/alert binding', () {
    test('alert events are counted, not silently dropped', () {
      final s = summarizeDay(
        [
          _event(NotificationEventType.alert, dogId: 'dog-a', at: day, id: 'g1'),
          _event(NotificationEventType.alert, dogId: 'dog-a', at: day, id: 'g2'),
        ],
        dogId: 'dog-a',
        day: day,
      );
      expect(s.alertCount, 2);
    });
  });

  group('summarizeWeek', () {
    test('buckets by local calendar day across 7 days', () {
      final events = [
        _event(NotificationEventType.bark,
            dogId: null, at: day.subtract(const Duration(days: 6)), id: 'w1'),
        _event(NotificationEventType.bark, dogId: null, at: day, id: 'w2'),
        _event(NotificationEventType.bark,
            dogId: null, at: day.subtract(const Duration(days: 8)), id: 'w3'),
      ];
      final week = summarizeWeek(events,
          dogId: 'dog-a', now: day, includeUntagged: true);
      expect(week.length, 7);
      expect(week.first.barkCount, 1); // oldest in-window day
      expect(week.last.barkCount, 1); // today
      expect(week.map((s) => s.barkCount).fold(0, (a, b) => a + b),
          2); // 8-days-ago excluded
    });
  });

  group('summarizeAll', () {
    test('includeUntagged applies to lifetime aggregate too', () {
      final events = [
        _event(NotificationEventType.treatDispensed, dogId: null, id: 'l1'),
        _event(NotificationEventType.alert, dogId: null, id: 'l2'),
      ];
      final strict = summarizeAll(events, dogId: 'dog-a');
      expect(strict.treatCount, 0);
      final loose = summarizeAll(events, dogId: 'dog-a', includeUntagged: true);
      expect(loose.treatCount, 1);
      expect(loose.alertCount, 1);
    });
  });
}
