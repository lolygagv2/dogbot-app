import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/conn_trace.dart';
import '../../data/datasources/dog_settings_api.dart';
import '../../l10n/l10n.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';
import 'l10n_provider.dart';
import 'settings_provider.dart';

/// Relay `quiet_hours` setting value: {enabled, start:"22:00", end:"07:00"}.
class QuietHours {
  final bool enabled;
  final String start; // HH:MM
  final String end; // HH:MM

  const QuietHours({this.enabled = false, this.start = '22:00', this.end = '07:00'});

  static QuietHours fromJson(Map<String, dynamic> j) => QuietHours(
        enabled: j['enabled'] == true,
        start: _hhmm(j['start']) ?? '22:00',
        end: _hhmm(j['end']) ?? '07:00',
      );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'start': start, 'end': end};

  QuietHours copyWith({bool? enabled, String? start, String? end}) => QuietHours(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
      );

  TimeOfDay get startTime => _tod(start);
  TimeOfDay get endTime => _tod(end);

  static String? _hhmm(dynamic v) {
    final s = v?.toString();
    if (s == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
  }

  static TimeOfDay _tod(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  static String format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class QuietHoursState {
  final QuietHours value;
  final int? version;
  final bool loaded;
  final bool loading;
  final bool saving;
  final String? error;

  /// Relay has no settings slice (404).
  final bool unsupported;
  final String? dogId;

  const QuietHoursState({
    this.value = const QuietHours(),
    this.version,
    this.loaded = false,
    this.loading = false,
    this.saving = false,
    this.error,
    this.unsupported = false,
    this.dogId,
  });

  QuietHoursState copyWith({
    QuietHours? value,
    int? version,
    bool? loaded,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    bool? unsupported,
    String? dogId,
  }) =>
      QuietHoursState(
        value: value ?? this.value,
        version: version ?? this.version,
        loaded: loaded ?? this.loaded,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        error: clearError ? null : (error ?? this.error),
        unsupported: unsupported ?? this.unsupported,
        dogId: dogId ?? this.dogId,
      );
}

/// Quiet hours for the selected dog — GET/PUT
/// `/api/dogs/{dog}/settings/quiet_hours` with optimistic versioning
/// (409 → reload, retry once). Cloud only.
final quietHoursProvider =
    StateNotifierProvider<QuietHoursNotifier, QuietHoursState>(
        (ref) => QuietHoursNotifier(ref));

class QuietHoursNotifier extends StateNotifier<QuietHoursState> {
  static const key = 'quiet_hours';
  final Ref _ref;

  QuietHoursNotifier(this._ref) : super(const QuietHoursState()) {
    _ref.listen<String?>(selectedDogProvider.select((d) => d?.id), (prev, next) {
      if (next != null && next != prev) load();
    });
  }

  AppLocalizations get _l => _ref.read(l10nProvider);
  String? get _token => _ref.read(settingsProvider).localModeEnabled
      ? null
      : _ref.read(authProvider).token;
  String? get _dogId => _ref.read(selectedDogProvider)?.id;

  Future<void> load() async {
    final token = _token, dogId = _dogId;
    if (token == null || dogId == null) {
      state = QuietHoursState(dogId: dogId, loaded: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true, dogId: dogId);
    final r = await _ref.read(dogSettingsApiProvider).get(token, dogId, key);
    if (!mounted) return;
    if (r.row != null) {
      state = QuietHoursState(
        dogId: dogId,
        value: QuietHours.fromJson(r.row!.value),
        version: r.row!.version,
        loaded: true,
      );
    } else if (r.unsupported) {
      state = QuietHoursState(dogId: dogId, unsupported: true);
    } else {
      state = state.copyWith(loading: false, error: r.error);
    }
  }

  Future<void> setEnabled(bool enabled) =>
      _save(state.value.copyWith(enabled: enabled));
  Future<void> setStart(TimeOfDay t) =>
      _save(state.value.copyWith(start: QuietHours.format(t)));
  Future<void> setEnd(TimeOfDay t) =>
      _save(state.value.copyWith(end: QuietHours.format(t)));

  Future<void> _save(QuietHours next, {bool retried = false}) async {
    final token = _token, dogId = state.dogId ?? _dogId;
    if (token == null || dogId == null || state.saving) return;
    final before = state.value;
    state = state.copyWith(value: next, saving: true, clearError: true);
    final r = await _ref.read(dogSettingsApiProvider).put(
          token,
          dogId,
          key,
          next.toJson(),
          expectedVersion: state.version,
        );
    if (!mounted) return;
    if (r.row != null) {
      state = state.copyWith(
        value: QuietHours.fromJson(r.row!.value),
        version: r.row!.version,
        saving: false,
        loaded: true,
      );
      connTrace('quiet-hours', 'saved ${next.toJson()} v${r.row!.version}');
      return;
    }
    if (r.conflict && !retried) {
      // Changed elsewhere (assistant / another phone): take the new version
      // and re-apply this edit once.
      await load();
      if (!mounted) return;
      return _save(next, retried: true);
    }
    state = state.copyWith(
      value: before,
      saving: false,
      error: _l.quietHoursErrSave(r.error ?? (r.conflict ? 'version' : '?')),
    );
  }
}
