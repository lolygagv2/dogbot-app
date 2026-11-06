import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/ai_connect_api.dart';
import '../../data/models/ai_connection.dart';
import '../../l10n/l10n.dart';
import 'agent_transcript_provider.dart';
import 'ai_connect_provider.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';
import 'l10n_provider.dart';
import 'notifications_provider.dart';
import 'settings_provider.dart';

enum DraftStatus { pending, approved, declined, expired }

class MissionDraftEntry {
  final MissionDraft draft;
  final DraftStatus status;
  final bool busy;
  final String? error;
  final String? missionId; // after approve (relay echo)

  const MissionDraftEntry({
    required this.draft,
    this.status = DraftStatus.pending,
    this.busy = false,
    this.error,
    this.missionId,
  });

  MissionDraftEntry copyWith(
          {DraftStatus? status, bool? busy, String? error, String? missionId}) =>
      MissionDraftEntry(
        draft: draft,
        status: status ?? this.status,
        busy: busy ?? this.busy,
        error: error,
        missionId: missionId ?? this.missionId,
      );
}

/// Drafted missions awaiting the owner's approve/decline. Fed by WS
/// `mission_draft` (relay `send_to_user_apps`, no replay) and hydrated from
/// `GET …/missions/drafts?status=all` on start / dog switch so a draft that
/// arrived while the app was closed still gets its feed tile.
/// `mission_draft_status` (B165 contract, optional) updates an entry.
final missionDraftsProvider =
    StateNotifierProvider<MissionDraftsNotifier, List<MissionDraftEntry>>(
        (ref) => MissionDraftsNotifier(ref));

/// Lookup by draft id (feed tiles read their status from here).
final missionDraftProvider =
    Provider.family<MissionDraftEntry?, String>((ref, id) {
  for (final e in ref.watch(missionDraftsProvider)) {
    if (e.draft.id == id) return e;
  }
  return null;
});

final pendingDraftCountProvider = Provider<int>((ref) => ref
    .watch(missionDraftsProvider)
    .where((e) => e.status == DraftStatus.pending)
    .length);

class MissionDraftsNotifier extends StateNotifier<List<MissionDraftEntry>> {
  final Ref _ref;
  StreamSubscription? _sub;
  bool _refreshing = false;

  AppLocalizations get _l => _ref.read(l10nProvider);

  MissionDraftsNotifier(this._ref) : super(const []) {
    _sub = _ref.read(websocketClientProvider).eventStream.listen((e) {
      switch (e.type) {
        case 'mission_draft':
          final draft = MissionDraft.fromEvent(e.data);
          if (draft != null) _add(draft);
          break;
        case 'mission_draft_status':
          _applyStatus(e.data);
          break;
      }
    });
    _ref.listen<String?>(
      selectedDogProvider.select((d) => d?.id),
      (prev, next) {
        if (next != null && prev != next) refresh();
      },
    );
    // Hydrate once the provider is first used (async; never throws).
    Future.microtask(refresh);
  }

  static DraftStatus _statusFromWire(String? s) => switch (s) {
        'approved' || 'approve' => DraftStatus.approved,
        'declined' || 'decline' || 'rejected' => DraftStatus.declined,
        'expired' => DraftStatus.expired,
        _ => DraftStatus.pending,
      };

  /// Display name for whoever proposed [d]: the wire's name, the connector's
  /// client_name (when the Connected AI list is loaded), the voice agent, or
  /// a generic fallback.
  String proposerName(MissionDraft d) {
    if (d.proposedBy != null && d.proposedBy!.isNotEmpty) return d.proposedBy!;
    switch (d.actorKind) {
      case DraftActorKind.agent:
        return _l.draftActorVoiceAgent;
      case DraftActorKind.connector:
        return _ref.read(aiConnectProvider.notifier).nameForClient(d.actorClientId) ??
            d.provider?.displayName ??
            _l.aiAssistantFallback;
      case DraftActorKind.app:
        return _l.draftTranscriptYou;
      case DraftActorKind.unknown:
        return d.provider?.displayName ?? _l.aiAssistantFallback;
    }
  }

  /// Pull the relay's draft list for the selected dog (cloud only).
  Future<void> refresh() async {
    if (_refreshing) return;
    if (_ref.read(settingsProvider).localModeEnabled) return;
    final token = _ref.read(authProvider).token;
    final dogId = _ref.read(selectedDogProvider)?.id;
    if (token == null || dogId == null) return;
    _refreshing = true;
    try {
      final drafts =
          await _ref.read(aiConnectApiProvider).listDrafts(token, dogId);
      if (!mounted || drafts == null) return;
      var added = 0;
      for (final d in drafts) {
        final st = _statusFromWire(d.status);
        final idx = state.indexWhere((e) => e.draft.id == d.id);
        if (idx < 0) {
          state = [...state, MissionDraftEntry(draft: d, status: st)];
          added++;
        } else if (!state[idx].busy && state[idx].status != st) {
          state = [
            for (final e in state)
              if (e.draft.id == d.id) e.copyWith(status: st) else e,
          ];
        }
        // Make sure the feed has a tile to act on (idempotent by id).
        _ref.read(notificationsProvider.notifier).ensureDraftNotification(
              d,
              title: _l.notifMissionDraftFrom(proposerName(d)),
            );
      }
      _trim();
      connTrace('mission-draft', 'hydrated ${drafts.length} drafts for $dogId (+$added)');
    } finally {
      _refreshing = false;
    }
  }

  void _add(MissionDraft draft) {
    if (state.any((d) => d.draft.id == draft.id)) return;
    final who = proposerName(draft);
    connTrace('mission-draft', 'received ${draft.id} "${draft.title}" from $who');
    state = [MissionDraftEntry(draft: draft), ...state];
    _trim();
    _ref.read(agentTranscriptProvider.notifier).appendLocal(
          who,
          _l.draftTranscriptProposed(draft.title),
          role: 'assistant',
        );
  }

  /// Relay activity-history row for a draft (hydrated on launch). Adds it
  /// if unseen so its feed tile can still be acted on; a status in the row
  /// (approved/declined/expired) wins over pending.
  void registerFromHistory(MissionDraft draft, {String? status}) {
    if (state.any((d) => d.draft.id == draft.id)) return;
    state = [
      ...state,
      MissionDraftEntry(draft: draft, status: _statusFromWire(status ?? draft.status)),
    ];
    _trim();
  }

  void _applyStatus(Map<String, dynamic> d) {
    final id = (d['draft_id'] ?? d['id'])?.toString();
    final raw = (d['status'] ?? d['decision'])?.toString();
    if (id == null || raw == null) return;
    final status = _statusFromWire(raw);
    if (status == DraftStatus.pending) return;
    state = [
      for (final e in state)
        if (e.draft.id == id)
          e.copyWith(
              status: status,
              busy: false,
              missionId: d['mission_id']?.toString())
        else
          e,
    ];
  }

  /// Approve or decline. Cloud: `PUT …/missions/drafts/{id}` (the relay owns
  /// drafts; approve appends the mission to the dog's `missions` setting).
  /// Local-AP: WS command `mission_draft_decision` for the robot to forward.
  Future<bool> decide(String draftId, DraftDecision decision) async {
    final idx = state.indexWhere((e) => e.draft.id == draftId);
    if (idx < 0) return false;
    final entry = state[idx];
    if (entry.busy || entry.status != DraftStatus.pending) return false;
    _set(draftId, entry.copyWith(busy: true));

    final isLocal = _ref.read(settingsProvider).localModeEnabled;
    final token = isLocal ? null : _ref.read(authProvider).token;
    final dogId = entry.draft.dogId ?? _ref.read(selectedDogProvider)?.id;

    DraftStatus status = decision == DraftDecision.approve
        ? DraftStatus.approved
        : DraftStatus.declined;
    String? missionId;
    String? error;

    if (token != null && dogId != null) {
      final r = await _ref
          .read(aiConnectApiProvider)
          .decideDraft(token, dogId, draftId, decision);
      error = r.error;
      missionId = r.missionId;
      if (r.error == null && r.status != null) status = _statusFromWire(r.status);
    } else if (isLocal) {
      _ref.read(websocketClientProvider).sendCommand('mission_draft_decision', {
        'draft_id': draftId,
        'decision': decision.name,
        if (dogId != null) 'dog_id': dogId,
      });
    } else {
      error = _l.aiErrSignedOut;
    }
    if (!mounted) return error == null;

    if (error != null) {
      _set(draftId, entry.copyWith(busy: false, error: error));
      connTrace('mission-draft', '$draftId → ${decision.name} FAILED: $error');
      return false;
    }
    _set(draftId,
        entry.copyWith(status: status, busy: false, missionId: missionId));
    connTrace('mission-draft',
        '$draftId → ${status.name}${missionId != null ? ' mission=$missionId' : ''}');
    _ref.read(agentTranscriptProvider.notifier).appendLocal(
          _l.draftTranscriptYou,
          status == DraftStatus.approved
              ? _l.draftTranscriptApproved(entry.draft.title)
              : _l.draftTranscriptDeclined(entry.draft.title),
          role: 'user',
        );
    return true;
  }

  void _set(String id, MissionDraftEntry next) {
    state = [for (final e in state) e.draft.id == id ? next : e];
  }

  void _trim() {
    if (state.length > 50) state = state.take(50).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
