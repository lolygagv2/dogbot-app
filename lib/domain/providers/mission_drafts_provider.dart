import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/ai_connect_api.dart';
import '../../data/models/ai_connection.dart';
import '../../l10n/l10n.dart';
import 'agent_transcript_provider.dart';
import 'auth_provider.dart';
import 'l10n_provider.dart';
import 'settings_provider.dart';

enum DraftStatus { pending, approved, declined, expired }

class MissionDraftEntry {
  final MissionDraft draft;
  final DraftStatus status;
  final bool busy;
  final String? error;

  const MissionDraftEntry({
    required this.draft,
    this.status = DraftStatus.pending,
    this.busy = false,
    this.error,
  });

  MissionDraftEntry copyWith({DraftStatus? status, bool? busy, String? error}) =>
      MissionDraftEntry(
        draft: draft,
        status: status ?? this.status,
        busy: busy ?? this.busy,
        error: error,
      );
}

/// Drafted missions awaiting the owner's approve/decline. Fed by WS
/// `mission_draft`; `mission_draft_status` (relay echo after a decision made
/// elsewhere, or expiry) updates an existing entry.
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
  }

  void _add(MissionDraft draft) {
    if (state.any((d) => d.draft.id == draft.id)) return;
    connTrace('mission-draft', 'received ${draft.id} "${draft.title}" from ${draft.proposedBy}');
    state = [MissionDraftEntry(draft: draft), ...state].take(50).toList();
    _ref.read(agentTranscriptProvider.notifier).appendLocal(
          draft.proposedBy ?? _l.aiAssistantFallback,
          _l.draftTranscriptProposed(draft.title),
          role: 'assistant',
        );
  }

  /// Relay activity-history row for a draft (hydrated on launch). Adds it
  /// if unseen so its feed tile can still be acted on; a status in the row
  /// (approved/declined/expired) wins over pending.
  void registerFromHistory(MissionDraft draft, {String? status}) {
    if (state.any((d) => d.draft.id == draft.id)) return;
    final st = switch (status) {
      'approved' => DraftStatus.approved,
      'declined' || 'rejected' => DraftStatus.declined,
      'expired' => DraftStatus.expired,
      _ => DraftStatus.pending,
    };
    state = [...state, MissionDraftEntry(draft: draft, status: st)]
        .take(50)
        .toList();
  }

  void _applyStatus(Map<String, dynamic> d) {
    final id = (d['draft_id'] ?? d['id'])?.toString();
    final status = switch ((d['status'] ?? d['decision'])?.toString()) {
      'approved' || 'approve' => DraftStatus.approved,
      'declined' || 'decline' || 'rejected' => DraftStatus.declined,
      'expired' => DraftStatus.expired,
      _ => null,
    };
    if (id == null || status == null) return;
    state = [
      for (final e in state)
        if (e.draft.id == id) e.copyWith(status: status, busy: false) else e,
    ];
  }

  /// Approve or decline. REST first (relay owns drafts); WS command fallback
  /// in local mode or when the REST slice isn't there.
  Future<bool> decide(String draftId, DraftDecision decision) async {
    final idx = state.indexWhere((e) => e.draft.id == draftId);
    if (idx < 0) return false;
    final entry = state[idx];
    if (entry.busy || entry.status != DraftStatus.pending) return false;
    _set(draftId, entry.copyWith(busy: true));

    String? error;
    final isLocal = _ref.read(settingsProvider).localModeEnabled;
    final token = isLocal ? null : _ref.read(authProvider).token;
    var sent = false;
    if (token != null) {
      error = await _ref
          .read(aiConnectApiProvider)
          .decideDraft(token, draftId, decision);
      sent = error == null;
    }
    if (!sent) {
      // Fallback: let the robot/relay pick it up off the command channel.
      _ref.read(websocketClientProvider).sendCommand('mission_draft_decision', {
        'draft_id': draftId,
        'decision': decision.name,
      });
      sent = true;
      error = null;
    }
    if (!mounted) return sent;

    final status = decision == DraftDecision.approve
        ? DraftStatus.approved
        : DraftStatus.declined;
    _set(draftId, entry.copyWith(status: status, busy: false, error: error));
    connTrace('mission-draft', '$draftId → ${decision.name}');
    _ref.read(agentTranscriptProvider.notifier).appendLocal(
          _l.draftTranscriptYou,
          decision == DraftDecision.approve
              ? _l.draftTranscriptApproved(entry.draft.title)
              : _l.draftTranscriptDeclined(entry.draft.title),
          role: 'user',
        );
    return sent;
  }

  void _set(String id, MissionDraftEntry next) {
    state = [for (final e in state) e.draft.id == id ? next : e];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
