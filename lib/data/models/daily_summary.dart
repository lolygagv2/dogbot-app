import '../../core/utils/time_utils.dart';

/// Per-dog daily summary — the "Today card" (GET /summary/{dog}/{date}).
///
/// Contract: `.claude/APP_CONTRACT_AI_SUMMIT_DEMO_2026-11-05.md` §1. Every
/// field is optional on the wire; parsing is lenient so a partial payload
/// (e.g. stats only, no headline, no plan) still renders. `headline` and
/// `plan` text are pre-phrased server-side — display verbatim.
class DailySummary {
  final String? dogId;
  final String? dogName;
  final String date; // YYYY-MM-DD as requested
  final String? headline;
  final DailyStats stats;
  final List<DailyHighlight> highlights;

  /// Optional AI-generated plan for the day. Null when no assistant has
  /// produced one — the card must look complete without it.
  final DailyPlan? plan;
  final DateTime fetchedAt;

  const DailySummary({
    this.dogId,
    this.dogName,
    required this.date,
    this.headline,
    this.stats = const DailyStats(),
    this.highlights = const [],
    this.plan,
    required this.fetchedAt,
  });

  static DailySummary fromJson(Map<String, dynamic> json, {String? date}) {
    final rawStats = json['stats'] is Map
        ? (json['stats'] as Map).cast<String, dynamic>()
        : json; // tolerate flat payloads
    return DailySummary(
      dogId: json['dog_id']?.toString(),
      dogName: json['dog_name']?.toString(),
      date: json['date']?.toString() ?? date ?? '',
      headline: _nonEmpty(json['headline']),
      stats: DailyStats.fromJson(rawStats),
      highlights: _highlights(json['highlights']),
      plan: DailyPlan.fromJson(json['plan']),
      fetchedAt: DateTime.now(),
    );
  }

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

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

class DailyStats {
  final int barks;
  final int treats;
  final int sits;
  final int coachingAttempts;
  final int coachingCompleted;
  final int quietMinutes;
  final int guardianInterventions;

  const DailyStats({
    this.barks = 0,
    this.treats = 0,
    this.sits = 0,
    this.coachingAttempts = 0,
    this.coachingCompleted = 0,
    this.quietMinutes = 0,
    this.guardianInterventions = 0,
  });

  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  static DailyStats fromJson(Map<String, dynamic> j) => DailyStats(
        barks: _i(j['barks']),
        treats: _i(j['treats']),
        sits: _i(j['sits']),
        coachingAttempts: _i(j['coaching_attempts']),
        coachingCompleted: _i(j['coaching_completed']),
        quietMinutes: _i(j['quiet_minutes']),
        guardianInterventions: _i(j['guardian_interventions']),
      );

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
