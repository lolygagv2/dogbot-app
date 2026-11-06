import '../../core/utils/time_utils.dart';

/// Per-dog daily roll-up — the "Today card" (GET /summary/{dog}/{date}).
///
/// Wire shape (relay `event_store.py`, brief 2026-11-06):
/// ```
/// {dog_id, date, tz, event_count,
///  counts:{bark_episode,intervention,settle,pacing,departure,arrival,treat,music,mission_run},
///  totals:{bark_s,pacing_s,music_s,treats,treat_cap,alone_s,interventions_by_kind{},
///          missions_success,missions_fail},
///  time_to_settle:{n,unresolved,median_s,mean_s,min_s,max_s},
///  top_episodes:[{event_id,ts,duration_s,bark_count,severity,settle_s,interventions[],image_url}],
///  first_event_ts,last_event_ts}
/// ```
/// The B165 draft shape (`stats{}` / `headline` / `highlights` / `plan`) is
/// still accepted so a robot serving the path locally may use either. Every
/// field is optional on the wire; parsing is lenient.
class DailySummary {
  final String? dogId;
  final String? dogName;
  final String date; // YYYY-MM-DD as the server resolved it
  final String? tz;
  final String? headline;
  final DailyStats stats;
  final List<DailyHighlight> highlights;

  /// Relay `top_episodes` (worst bark episodes of the day, max 3).
  final List<DailyEpisode> episodes;

  /// Optional AI-generated plan. Null when no assistant produced one — the
  /// card must look complete without it.
  final DailyPlan? plan;

  /// Relay `event_count`; null when the server didn't send one (draft shape).
  final int? eventCount;
  final DateTime fetchedAt;

  const DailySummary({
    this.dogId,
    this.dogName,
    required this.date,
    this.tz,
    this.headline,
    this.stats = const DailyStats(),
    this.highlights = const [],
    this.episodes = const [],
    this.plan,
    this.eventCount,
    required this.fetchedAt,
  });

  /// True when the relay has no events for the day — the card then falls
  /// back to counts derived from this phone's activity feed.
  bool get isEmpty => (eventCount ?? 0) == 0 && stats.isZero && episodes.isEmpty;

  static DailySummary fromJson(Map<String, dynamic> json, {String? date}) {
    final hasRelayShape = json['counts'] is Map || json['totals'] is Map;
    final DailyStats stats;
    if (hasRelayShape) {
      stats = DailyStats.fromRelay(
        counts: _map(json['counts']),
        totals: _map(json['totals']),
        settle: _map(json['time_to_settle']),
      );
    } else {
      stats = DailyStats.fromJson(
          json['stats'] is Map ? _map(json['stats']) : json);
    }
    return DailySummary(
      dogId: json['dog_id']?.toString(),
      dogName: json['dog_name']?.toString(),
      date: json['date']?.toString() ?? date ?? '',
      tz: _nonEmpty(json['tz']),
      headline: _nonEmpty(json['headline']),
      stats: stats,
      highlights: _highlights(json['highlights']),
      episodes: _episodes(json['top_episodes']),
      plan: DailyPlan.fromJson(json['plan']),
      eventCount: (json['event_count'] as num?)?.toInt(),
      fetchedAt: DateTime.now(),
    );
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : const {};

  static List<DailyHighlight> _highlights(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final h in raw)
        if (h is Map && _nonEmpty(h['text']) != null)
          DailyHighlight(
            time: _nonEmpty(h['time']),
            text: h['text'].toString(),
            imageUrl: _nonEmpty(h['image_url'] ?? h['snapshot_url']),
          )
        else if (h is String && h.isNotEmpty)
          DailyHighlight(text: h),
    ];
  }

  static List<DailyEpisode> _episodes(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) DailyEpisode.fromJson(e.cast<String, dynamic>()),
    ];
  }

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

class DailyStats {
  // Relay counts
  final int barks; // bark_episode count
  final int treats;
  final int? treatCap;
  final int guardianInterventions; // counts.intervention
  final int settles;
  final int pacingCount;
  final int departures;
  final int arrivals;
  final int musicPlays;
  final int missionRuns;
  // Relay totals (seconds)
  final int barkSeconds;
  final int pacingSeconds;
  final int musicSeconds;
  final int aloneSeconds;
  final int missionsSuccess;
  final int missionsFail;
  final Map<String, int> interventionsByKind;
  // Relay time_to_settle
  final int? settleMedianS;
  final int settleN;
  final int settleUnresolved;
  // Draft-shape (B165) fields, kept for a locally served summary
  final int sits;
  final int coachingAttempts;
  final int coachingCompleted;
  final int quietMinutes;

  const DailyStats({
    this.barks = 0,
    this.treats = 0,
    this.treatCap,
    this.guardianInterventions = 0,
    this.settles = 0,
    this.pacingCount = 0,
    this.departures = 0,
    this.arrivals = 0,
    this.musicPlays = 0,
    this.missionRuns = 0,
    this.barkSeconds = 0,
    this.pacingSeconds = 0,
    this.musicSeconds = 0,
    this.aloneSeconds = 0,
    this.missionsSuccess = 0,
    this.missionsFail = 0,
    this.interventionsByKind = const {},
    this.settleMedianS,
    this.settleN = 0,
    this.settleUnresolved = 0,
    this.sits = 0,
    this.coachingAttempts = 0,
    this.coachingCompleted = 0,
    this.quietMinutes = 0,
  });

  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static int? _in(dynamic v) => (v as num?)?.toInt();

  /// Relay roll-up: `counts` + `totals` + `time_to_settle`.
  static DailyStats fromRelay({
    required Map<String, dynamic> counts,
    required Map<String, dynamic> totals,
    required Map<String, dynamic> settle,
  }) {
    final byKind = <String, int>{};
    final rawKinds = totals['interventions_by_kind'];
    if (rawKinds is Map) {
      rawKinds.forEach((k, v) => byKind[k.toString()] = _i(v));
    }
    final success = _i(totals['missions_success']);
    final fail = _i(totals['missions_fail']);
    return DailyStats(
      barks: _i(counts['bark_episode']),
      treats: _in(totals['treats']) ?? _i(counts['treat']),
      treatCap: _in(totals['treat_cap']),
      guardianInterventions: _i(counts['intervention']),
      settles: _i(counts['settle']),
      pacingCount: _i(counts['pacing']),
      departures: _i(counts['departure']),
      arrivals: _i(counts['arrival']),
      musicPlays: _i(counts['music']),
      missionRuns: _i(counts['mission_run']),
      barkSeconds: _i(totals['bark_s']),
      pacingSeconds: _i(totals['pacing_s']),
      musicSeconds: _i(totals['music_s']),
      aloneSeconds: _i(totals['alone_s']),
      missionsSuccess: success,
      missionsFail: fail,
      interventionsByKind: byKind,
      settleMedianS: _in(settle['median_s']),
      settleN: _i(settle['n']),
      settleUnresolved: _i(settle['unresolved']),
      // Missions double as "coaching" on the card when the draft fields are absent.
      coachingAttempts: success + fail,
      coachingCompleted: success,
    );
  }

  /// B165 draft shape (`stats{}` or flat).
  static DailyStats fromJson(Map<String, dynamic> j) => DailyStats(
        barks: _i(j['barks']),
        treats: _i(j['treats']),
        sits: _i(j['sits']),
        coachingAttempts: _i(j['coaching_attempts']),
        coachingCompleted: _i(j['coaching_completed']),
        quietMinutes: _i(j['quiet_minutes']),
        guardianInterventions: _i(j['guardian_interventions']),
      );

  bool get isZero =>
      barks == 0 &&
      treats == 0 &&
      guardianInterventions == 0 &&
      pacingCount == 0 &&
      musicPlays == 0 &&
      missionRuns == 0 &&
      departures == 0 &&
      sits == 0 &&
      coachingAttempts == 0 &&
      quietMinutes == 0;

  double? get coachingSuccessRate =>
      coachingAttempts > 0 ? coachingCompleted / coachingAttempts : null;
}

class DailyHighlight {
  final String? time;
  final String text;
  final String? imageUrl;
  const DailyHighlight({this.time, required this.text, this.imageUrl});

  /// Highlight time parsed when it is an ISO instant; null for "HH:MM".
  DateTime? get instant => time == null ? null : tryParseServerTimestamp(time);
}

/// One of the relay's `top_episodes` (worst bark episodes of the day).
class DailyEpisode {
  final String? eventId;
  final DateTime? ts;
  final int durationS;
  final int barkCount;
  final String? severity; // low | med | high
  final int? settleS;
  final List<String> interventions;
  final String? imageUrl;

  const DailyEpisode({
    this.eventId,
    this.ts,
    this.durationS = 0,
    this.barkCount = 0,
    this.severity,
    this.settleS,
    this.interventions = const [],
    this.imageUrl,
  });

  static DailyEpisode fromJson(Map<String, dynamic> j) => DailyEpisode(
        eventId: j['event_id']?.toString(),
        ts: tryParseServerTimestamp(j['ts']?.toString()),
        durationS: (j['duration_s'] as num?)?.toInt() ?? 0,
        barkCount: (j['bark_count'] as num?)?.toInt() ?? 0,
        severity: j['severity']?.toString(),
        settleS: (j['settle_s'] as num?)?.toInt(),
        interventions: j['interventions'] is List
            ? (j['interventions'] as List).map((e) => e.toString()).toList()
            : const [],
        imageUrl: DailySummary._nonEmpty(j['image_url']),
      );
}

class DailyPlan {
  /// Which assistant produced it: chatgpt | claude | grok | perplexity | wimz
  final String? source;
  final String? title;
  final List<String> items;
  const DailyPlan({this.source, this.title, this.items = const []});

  static DailyPlan? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final items = <String>[
      if (raw['items'] is List)
        for (final i in raw['items'] as List)
          if (i != null && i.toString().isNotEmpty) i.toString(),
    ];
    final title = raw['title']?.toString();
    if (items.isEmpty && (title == null || title.isEmpty)) return null;
    return DailyPlan(
      source: raw['source']?.toString(),
      title: (title == null || title.isEmpty) ? null : title,
      items: items,
    );
  }
}
