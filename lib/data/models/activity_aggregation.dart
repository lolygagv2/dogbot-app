import 'dog_profile.dart';
import 'notification_event.dart';

/// Real-data aggregation of activity events into [DogDailySummary] buckets.
///
/// Replaces the former hardcoded/random mock summaries. Counts are derived
/// purely from the notification/activity history the app already ingests
/// (live WS + relay REST hydrate), so dashboards reflect what actually
/// happened — never fabricated numbers.

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Summarize one calendar day for a dog.
/// [dogId] empty → aggregate across all dogs (and untagged events).
/// Per-dog (non-empty [dogId]) counts ONLY events tagged with that exact
/// dog_id — untagged events are excluded (matches the C4 per-dog rule).
DogDailySummary summarizeDay(
  List<NotificationEvent> events, {
  required String dogId,
  required DateTime day,
}) {
  final allDogs = dogId.isEmpty;
  var treats = 0, sits = 0, barks = 0, missions = 0, missionSuccess = 0;

  for (final e in events) {
    if (!_sameDay(e.timestamp, day)) continue;
    if (!allDogs && e.dogId != dogId) continue;

    switch (e.type) {
      case NotificationEventType.treatDispensed:
        treats++;
        break;
      case NotificationEventType.sit:
      case NotificationEventType.lieDown:
      case NotificationEventType.stand:
        sits++;
        break;
      case NotificationEventType.bark:
        barks++;
        break;
      case NotificationEventType.coachReward:
        // Coach rewards are a positive behavior detection too.
        sits++;
        break;
      case NotificationEventType.missionCompleted:
        missions++;
        missionSuccess++;
        break;
      case NotificationEventType.missionFailed:
        missions++;
        break;
      default:
        break;
    }
  }

  // Simple, honest goal heuristic: positive behaviors toward a daily target
  // of 10. No fabricated baseline — 0 events → 0 progress.
  final goal = ((treats + sits) / 10).clamp(0.0, 1.0).toDouble();

  return DogDailySummary(
    dogId: dogId,
    date: day,
    treatCount: treats,
    sitCount: sits,
    barkCount: barks,
    missionCount: missions,
    missionSuccessCount: missionSuccess,
    goalProgress: goal,
  );
}

/// Summarize the last 7 days (oldest → newest) for the dashboard chart.
/// [now] is injectable for testing; defaults to DateTime.now().
List<DogDailySummary> summarizeWeek(
  List<NotificationEvent> events, {
  required String dogId,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    return summarizeDay(events, dogId: dogId, day: day);
  });
}

/// Aggregate every available event for a dog into a single summary (best-effort
/// "lifetime", bounded by however much history the app currently holds).
DogDailySummary summarizeAll(
  List<NotificationEvent> events, {
  required String dogId,
}) {
  final allDogs = dogId.isEmpty;
  var treats = 0, sits = 0, barks = 0, missions = 0, missionSuccess = 0;

  for (final e in events) {
    if (!allDogs && e.dogId != dogId) continue;
    switch (e.type) {
      case NotificationEventType.treatDispensed:
        treats++;
        break;
      case NotificationEventType.sit:
      case NotificationEventType.lieDown:
      case NotificationEventType.stand:
      case NotificationEventType.coachReward:
        sits++;
        break;
      case NotificationEventType.bark:
        barks++;
        break;
      case NotificationEventType.missionCompleted:
        missions++;
        missionSuccess++;
        break;
      case NotificationEventType.missionFailed:
        missions++;
        break;
      default:
        break;
    }
  }

  return DogDailySummary(
    dogId: dogId,
    date: DateTime.now(),
    treatCount: treats,
    sitCount: sits,
    barkCount: barks,
    missionCount: missions,
    missionSuccessCount: missionSuccess,
    goalProgress: ((treats + sits) / 10).clamp(0.0, 1.0).toDouble(),
  );
}
