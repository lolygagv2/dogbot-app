import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/daily_summary.dart';

void main() {
  test('day summary: guard time, settle median + longest, steps, still', () {
    final s = DailySummary.fromJson({
      'dog_id': 'd1',
      'date': '2026-11-18',
      'event_count': 39,
      'counts': {'bark_episode': 4, 'intervention': 16, 'settle': 4},
      'totals': {
        'bark_s': 840,
        'treats': 10,
        'treat_cap': null,
        'sg_s': 18298,
        'interventions_by_kind': {'sound': 4, 'voice': 4, 'treat': 4, 'approach': 4},
      },
      'time_to_settle': {'n': 4, 'median_s': 325, 'max_s': 560},
      'top_episodes': [
        {
          'event_id': 'replay:d1:2026-11-18:36',
          'ts': '2026-11-18T19:50:00+00:00',
          'duration_s': 360.0,
          'bark_count': 82,
          'severity': 'high',
          'settle_s': 560,
          'interventions': ['sound', 'voice', 'treat', 'approach'],
          'image_url': '/api/media/download/seed_bezik_bark_1450.png',
        },
      ],
    });
    expect(s.stats.guardSeconds, 18298);
    expect(s.stats.barks, 4);
    expect(s.stats.guardianInterventions, 16);
    expect(s.stats.interventionsByKind['approach'], 4);
    expect(s.stats.settleMedianS, 325);
    expect(s.stats.settleMaxS, 560);
    expect(s.stats.treats, 10);
    final e = s.episodes.single;
    expect(e.interventions, ['sound', 'voice', 'treat', 'approach']);
    expect(e.imageUrl, '/api/media/download/seed_bezik_bark_1450.png');
  });

  test('week comparison is per day: partial week vs whole week', () {
    // Wednesday (3 days in): 300 s so far vs 1400 s last week
    // → 100 s/day vs 200 s/day → down 50%.
    const down =
        BarkWeekCompare(thisWeekS: 300, lastWeekS: 1400, daysThisWeek: 3);
    expect(down.pctChange, closeTo(-50, 0.001));
    const up = BarkWeekCompare(thisWeekS: 840, lastWeekS: 101, daysThisWeek: 3);
    expect(up.pctChange! > 0, isTrue);
    // No barking last week: nothing to compare against.
    const none = BarkWeekCompare(thisWeekS: 840, lastWeekS: 0, daysThisWeek: 3);
    expect(none.pctChange, isNull);
  });
}
