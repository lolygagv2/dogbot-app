import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/summary_api.dart';
import '../../data/models/daily_summary.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

/// Today card state for one dog (family keyed by dog id).
class DailySummaryState {
  final DailySummary? summary;
  final bool loading;

  /// Server has nothing for today (404 path, or a relay roll-up with zero
  /// events). Not an error — the card falls back to counts derived from the
  /// local activity feed.
  final bool notFound;
  final String? error;

  /// This week's barking against last week's (relay weekly roll-ups); null
  /// until fetched, in local mode, or when the relay could not be read.
  final BarkWeekCompare? weekCompare;

  const DailySummaryState({
    this.summary,
    this.loading = false,
    this.notFound = false,
    this.error,
    this.weekCompare,
  });

  DailySummaryState copyWith({
    DailySummary? summary,
    bool? loading,
    bool? notFound,
    String? error,
    bool clearError = false,
  }) =>
      DailySummaryState(
        summary: summary ?? this.summary,
        loading: loading ?? this.loading,
        notFound: notFound ?? this.notFound,
        error: clearError ? null : (error ?? this.error),
        weekCompare: weekCompare,
      );
}

final dailySummaryProvider = StateNotifierProvider.family<
    DailySummaryNotifier, DailySummaryState, String>((ref, dogId) {
  return DailySummaryNotifier(ref, dogId);
});

/// YYYY-MM-DD in device-local time (the owner's "today").
String isoDateLocal(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

class DailySummaryNotifier extends StateNotifier<DailySummaryState> {
  final Ref _ref;
  final String _dogId;

  /// Day being shown when it is pinned (a replay's date, YYYY-MM-DD);
  /// null = the relay's "today" for the dog.
  String? _isoDate;

  /// A load asked for while one was in flight: run once more afterwards.
  bool _reloadQueued = false;
  StreamSubscription? _eventSub;
  Timer? _eventDebounce;

  DailySummaryNotifier(this._ref, this._dogId)
      : super(const DailySummaryState()) {
    // Event records for this dog (live or replayed) change the roll-up:
    // recompute shortly after the last one of a burst.
    _eventSub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'event')
        .listen((e) {
      final record = e.data['event'];
      if (record is! Map || record['dog_id']?.toString() != _dogId) return;
      _eventDebounce?.cancel();
      _eventDebounce = Timer(const Duration(seconds: 2), () {
        if (mounted) load(isoDate: _isoDate, refresh: true);
      });
    });
    load();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventDebounce?.cancel();
    super.dispose();
  }

  /// [refresh] asks the relay to recompute the roll-up (?refresh=1).
  /// [isoDate] (YYYY-MM-DD) pins the day; without it or [date] the relay's
  /// "today" is shown.
  Future<void> load(
      {DateTime? date, String? isoDate, bool refresh = false}) async {
    _isoDate = isoDate ?? (date != null ? isoDateLocal(date) : null);
    if (state.loading) {
      _reloadQueued = true;
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    // Local mode has no JWT; the robot serves the path unauthenticated and
    // needs a concrete date. The relay resolves `today` in the dog's
    // timezone, which beats guessing from the phone's clock.
    final isLocal = _ref.read(settingsProvider).localModeEnabled;
    final token = isLocal ? null : _ref.read(authProvider).token;
    final dateArg =
        _isoDate ?? (isLocal ? isoDateLocal(DateTime.now()) : 'today');
    final result = await _ref.read(summaryApiProvider).getDaily(
          dogId: _dogId,
          date: dateArg,
          token: token,
          refresh: refresh,
        );
    if (!mounted) return;
    final s = result.summary;
    if (s != null && !s.isEmpty) {
      state = DailySummaryState(summary: s, weekCompare: state.weekCompare);
    } else if (s != null || result.notFound) {
      // Relay answered but has no events for the day → local counts.
      state = DailySummaryState(
          summary: null, notFound: true, weekCompare: state.weekCompare);
    } else {
      connTrace('summary-load', 'dog=$_dogId error=${result.error}');
      state = DailySummaryState(
          summary: state.summary,
          error: result.error,
          weekCompare: state.weekCompare);
    }
    if (_reloadQueued) {
      _reloadQueued = false;
      unawaited(load(isoDate: _isoDate, refresh: true));
      return;
    }
    if (token != null) {
      unawaited(
          _loadWeekCompare(token, s?.date ?? _isoDate ?? isoDateLocal(DateTime.now())));
    }
  }

  /// Last week's bark seconds per week-start: a finished week doesn't change
  /// (unless a seed is loaded into it — a replay load clears this).
  final Map<String, int> _lastWeekBarkS = {};

  /// Forget cached past weeks (a replay load / reset rewrites history).
  void forgetPastWeeks() => _lastWeekBarkS.clear();

  Future<void> _loadWeekCompare(String token, String date) async {
    final day = DateTime.tryParse(date);
    if (day == null) return;
    final api = _ref.read(summaryApiProvider);
    final prevDate = isoDateLocal(
        DateTime(day.year, day.month, day.day).subtract(const Duration(days: 7)));
    final thisWeek =
        await api.getWeekBarkSeconds(dogId: _dogId, date: date, token: token);
    final lastWeek = _lastWeekBarkS[prevDate] ??
        await api.getWeekBarkSeconds(
            dogId: _dogId, date: prevDate, token: token);
    if (!mounted || thisWeek == null || lastWeek == null) return;
    _lastWeekBarkS[prevDate] = lastWeek;
    state = DailySummaryState(
      summary: state.summary,
      loading: state.loading,
      notFound: state.notFound,
      error: state.error,
      weekCompare: BarkWeekCompare(
          thisWeekS: thisWeek, lastWeekS: lastWeek, daysThisWeek: day.weekday),
    );
  }
}
