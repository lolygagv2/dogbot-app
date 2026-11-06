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

  /// Server has no rows for today (404). Not an error — the card falls back
  /// to counts derived from the local activity feed.
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

  Future<void> load({DateTime? date}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    final isoDate = isoDateLocal(date ?? DateTime.now());
    // Local mode has no JWT; the robot serves the path unauthenticated.
    final isLocal = _ref.read(settingsProvider).localModeEnabled;
    final token = isLocal ? null : _ref.read(authProvider).token;
    final result = await _ref
        .read(summaryApiProvider)
        .getDaily(dogId: _dogId, isoDate: isoDate, token: token);
    if (!mounted) return;
    if (result.summary != null) {
      state = DailySummaryState(summary: result.summary);
    } else if (result.notFound) {
      state = DailySummaryState(summary: state.summary, notFound: true);
    } else {
      connTrace('summary-load', 'dog=$_dogId error=${result.error}');
      state = DailySummaryState(summary: state.summary, error: result.error);
    }
  }
}
