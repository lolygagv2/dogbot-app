import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const DailySummaryState({
    this.summary,
    this.loading = false,
    this.notFound = false,
    this.error,
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

  DailySummaryNotifier(this._ref, this._dogId)
      : super(const DailySummaryState()) {
    load();
  }

  /// [refresh] asks the relay to recompute the roll-up (?refresh=1).
  Future<void> load({DateTime? date, bool refresh = false}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    // Local mode has no JWT; the robot serves the path unauthenticated and
    // needs a concrete date. The relay resolves `today` in the dog's
    // timezone, which beats guessing from the phone's clock.
    final isLocal = _ref.read(settingsProvider).localModeEnabled;
    final token = isLocal ? null : _ref.read(authProvider).token;
    final dateArg = (date != null || isLocal)
        ? isoDateLocal(date ?? DateTime.now())
        : 'today';
    final result = await _ref.read(summaryApiProvider).getDaily(
          dogId: _dogId,
          date: dateArg,
          token: token,
          refresh: refresh,
        );
    if (!mounted) return;
    final s = result.summary;
    if (s != null && !s.isEmpty) {
      state = DailySummaryState(summary: s);
    } else if (s != null || result.notFound) {
      // Relay answered but has no events for the day → local counts.
      state = DailySummaryState(summary: null, notFound: true);
    } else {
      connTrace('summary-load', 'dog=$_dogId error=${result.error}');
      state = DailySummaryState(summary: state.summary, error: result.error);
    }
  }
}
