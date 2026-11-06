import '../../core/utils/time_utils.dart';

/// Connected AI — assistants (ChatGPT, Claude, Grok, Perplexity) that reach
/// WIM-Z through the relay's MCP connector. Wire shapes per
/// `.claude/APP_BRIEF_FROM_RELAY_2026-11-06.md` §4/§5 (relay routers
/// `ai.py`, `mission_drafts.py`); the B165 draft shapes are still accepted.

/// The assistants we ship a setup guide for. Order = display order.
enum AiProvider {
  chatgpt,
  claude,
  grok,
  perplexity;

  static AiProvider? fromWire(String? v) {
    if (v == null) return null;
    final s = v.toLowerCase();
    for (final p in values) {
      if (s.contains(p.name)) return p;
    }
    if (s.contains('openai') || s.contains('gpt')) return AiProvider.chatgpt;
    if (s.contains('anthropic')) return AiProvider.claude;
    if (s.contains('xai')) return AiProvider.grok;
    return null;
  }

  /// Brand name as the vendor spells it (not localized).
  String get displayName => switch (this) {
        AiProvider.chatgpt => 'ChatGPT',
        AiProvider.claude => 'Claude',
        AiProvider.grok => 'Grok',
        AiProvider.perplexity => 'Perplexity',
      };
}

/// Connector scopes the relay's consent screen offers. `read` is implicit.
const kAiScopes = ['read', 'settings', 'missions', 'physical', 'photos', 'camera'];

/// One OAuth client holding an active token for this user
/// (`GET …/ai/connectors` → assistants[]).
class AiAssistant {
  final String id; // client_id
  final String name; // client_name
  final AiProvider? provider;
  final List<String> scopes;
  final DateTime? connectedAt;
  final DateTime? lastUsedAt;
  final int activeTokens;

  const AiAssistant({
    required this.id,
    required this.name,
    this.provider,
    this.scopes = const [],
    this.connectedAt,
    this.lastUsedAt,
    this.activeTokens = 0,
  });

  static AiAssistant fromJson(Map<String, dynamic> j) {
    final rawName = (j['client_name'] ?? j['name'])?.toString();
    final provider =
        AiProvider.fromWire(j['provider']?.toString() ?? rawName);
    return AiAssistant(
      id: (j['client_id'] ?? j['id'] ?? j['connection_id'] ?? '').toString(),
      name: (rawName != null && rawName.isNotEmpty)
          ? rawName
          : provider?.displayName ?? j['client_id']?.toString() ?? 'Assistant',
      provider: provider,
      scopes: _scopes(j['scopes'] ?? j['scope']),
      connectedAt: tryParseServerTimestamp(j['connected_at']?.toString()),
      lastUsedAt: tryParseServerTimestamp(j['last_used_at']?.toString()),
      activeTokens: (j['active_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  static List<String> _scopes(dynamic raw) {
    if (raw is List) return raw.map((s) => s.toString()).toList();
    if (raw is String && raw.isNotEmpty) return raw.split(RegExp(r'[ ,]+'));
    return const [];
  }
}

/// One `mcp_audit` row (`GET …/ai/audit` → entries[]):
/// {id, ts, actor, client_name, tool, dog_id, outcome ok|refused|denied_scope|error,
///  input, result_summary, duration_ms}
class AiAuditEntry {
  final String id;
  final DateTime ts;
  final String assistant; // client_name
  final AiProvider? provider;
  final String action; // tool
  final String? scope;
  final String result; // ok | refused | denied_scope | error (B165: denied)
  final String? detail; // result_summary
  final int? durationMs;

  const AiAuditEntry({
    required this.id,
    required this.ts,
    required this.assistant,
    this.provider,
    required this.action,
    this.scope,
    this.result = 'ok',
    this.detail,
    this.durationMs,
  });

  bool get isOk => result == 'ok' || result == 'success';

  static AiAuditEntry fromJson(Map<String, dynamic> j) {
    final name = (j['client_name'] ?? j['assistant'] ?? j['name'])?.toString();
    final provider = AiProvider.fromWire(j['provider']?.toString() ?? name);
    final actor = j['actor']?.toString();
    return AiAuditEntry(
      id: (j['id'] ?? j['ts'] ?? j['timestamp'] ?? '').toString(),
      ts: parseServerTimestamp((j['ts'] ?? j['timestamp'])?.toString()),
      assistant: (name != null && name.isNotEmpty)
          ? name
          : provider?.displayName ?? actor ?? '?',
      provider: provider,
      action: (j['tool'] ?? j['action'] ?? j['event'] ?? '').toString(),
      scope: j['scope']?.toString(),
      result: (j['outcome'] ?? j['result'] ?? j['status'] ?? 'ok')
          .toString()
          .toLowerCase(),
      detail: (j['result_summary'] ?? j['detail'] ?? j['summary'])?.toString(),
      durationMs: (j['duration_ms'] as num?)?.toInt(),
    );
  }
}

/// Everything the Connected AI screen shows (`GET …/ai/connectors` +
/// `GET …/ai/audit`).
class AiConnectionsState {
  final String? connectorUrl;
  final List<AiAssistant> assistants;
  final List<AiAuditEntry> audit;
  final bool loading;

  /// True while "Disconnect all" (`POST …/ai/revoke_all`) is in flight.
  final bool revokingAll;
  final String? error;

  /// True when the relay answered 404 — the slice isn't deployed yet.
  final bool unsupported;

  /// Dog the lists were loaded for (relay routes are dog-scoped).
  final String? dogId;

  const AiConnectionsState({
    this.connectorUrl,
    this.assistants = const [],
    this.audit = const [],
    this.loading = false,
    this.revokingAll = false,
    this.error,
    this.unsupported = false,
    this.dogId,
  });

  AiConnectionsState copyWith({
    String? connectorUrl,
    List<AiAssistant>? assistants,
    List<AiAuditEntry>? audit,
    bool? loading,
    bool? revokingAll,
    String? error,
    bool clearError = false,
    bool? unsupported,
    String? dogId,
  }) {
    return AiConnectionsState(
      connectorUrl: connectorUrl ?? this.connectorUrl,
      assistants: assistants ?? this.assistants,
      audit: audit ?? this.audit,
      loading: loading ?? this.loading,
      revokingAll: revokingAll ?? this.revokingAll,
      error: clearError ? null : (error ?? this.error),
      unsupported: unsupported ?? this.unsupported,
      dogId: dogId ?? this.dogId,
    );
  }
}

/// Who proposed a draft: relay `actor` label is `connector:<client_id>`,
/// `agent` (the WIM-Z voice agent) or `app:<user>`.
enum DraftActorKind { connector, agent, app, unknown }

/// A mission an assistant drafted and is asking the owner to approve.
///
/// Relay shape (WS `mission_draft` and `GET …/missions/drafts` rows):
/// ```
/// {draft_id, dog_id, actor, status?, created_at, decided_at?, mission_id?,
///  warnings:[..], note?, draft:{id,type,name,enabled,
///  trigger:{kind schedule|departure|manual, time, delay_s, cooldown_s, days[]},
///  duration_s, reward_treats, goal}}
/// ```
/// Decided via `PUT …/missions/drafts/{draft_id}` {decision}. The B165 flat
/// shape (title/summary/steps/proposed_by) is still accepted.
class MissionDraft {
  final String id; // draft_id
  final String title; // draft.name (or legacy title)
  final String? summary; // legacy summary, else goal
  final List<String> steps; // legacy only
  final String? proposedBy; // display name when the wire gave one
  final AiProvider? provider;
  final DraftActorKind actorKind;

  /// client_id for `connector:<id>` actors — resolved to a client_name via
  /// the Connected AI list when available.
  final String? actorClientId;
  final String? dogId;
  final String? dogName;
  final DateTime? expiresAt;
  final DateTime receivedAt;
  final DateTime? createdAt;

  // Relay mission definition
  final String? missionType;
  final String? missionId; // draft.id (becomes the mission id on approve)
  final String triggerKind; // schedule | departure | manual
  final String? triggerTime; // HH:MM for schedule
  final int? delayS;
  final List<String> days;
  final int? durationS;
  final int? rewardTreats;
  final String? goal;
  final List<String> warnings;

  /// Wire status for list rows (pending|approved|declined); null for WS.
  final String? status;

  const MissionDraft({
    required this.id,
    required this.title,
    this.summary,
    this.steps = const [],
    this.proposedBy,
    this.provider,
    this.actorKind = DraftActorKind.unknown,
    this.actorClientId,
    this.dogId,
    this.dogName,
    this.expiresAt,
    required this.receivedAt,
    this.createdAt,
    this.missionType,
    this.missionId,
    this.triggerKind = 'manual',
    this.triggerTime,
    this.delayS,
    this.days = const [],
    this.durationS,
    this.rewardTreats,
    this.goal,
    this.warnings = const [],
    this.status,
  });

  bool get isFromVoiceAgent => actorKind == DraftActorKind.agent;

  static MissionDraft? fromEvent(Map<String, dynamic> d) {
    final nested = d['draft'] is Map;
    final inner =
        nested ? (d['draft'] as Map).cast<String, dynamic>() : d;
    // Relay: draft_id lives on the envelope; draft.id is the MISSION id.
    final id = (d['draft_id'] ??
            (nested ? inner['draft_id'] : null) ??
            (nested ? null : inner['id']))
        ?.toString();
    if (id == null || id.isEmpty) return null;

    final actor = d['actor']?.toString();
    var kind = DraftActorKind.unknown;
    String? clientId;
    if (actor != null) {
      if (actor == 'agent' || actor.startsWith('agent:')) {
        kind = DraftActorKind.agent;
      } else if (actor.startsWith('connector:')) {
        kind = DraftActorKind.connector;
        clientId = actor.substring('connector:'.length);
      } else if (actor.startsWith('app:')) {
        kind = DraftActorKind.app;
      }
    }
    final legacyProposer =
        (inner['proposed_by'] ?? inner['assistant'] ?? d['assistant'])
            ?.toString();
    final provider = AiProvider.fromWire(
        (inner['provider'] ?? d['provider'] ?? legacyProposer ?? actor)
            ?.toString());

    final trigger = inner['trigger'] is Map
        ? (inner['trigger'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final name = _str(inner['name']) ??
        _str(inner['title']) ??
        _str(inner['mission_name']) ??
        _str(inner['type']) ??
        'Mission';

    return MissionDraft(
      id: id,
      title: name,
      summary: _str(inner['summary'] ?? inner['description']) ?? _str(inner['goal']),
      steps: inner['steps'] is List
          ? (inner['steps'] as List)
              .map((s) =>
                  s is Map ? (s['text'] ?? s['name'] ?? '').toString() : s.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
      proposedBy: legacyProposer ??
          (kind == DraftActorKind.connector ? null : provider?.displayName),
      provider: provider,
      actorKind: kind,
      actorClientId: clientId,
      dogId: (inner['dog_id'] ?? d['dog_id'])?.toString(),
      dogName: (inner['dog_name'] ?? d['dog_name'])?.toString(),
      expiresAt: tryParseServerTimestamp(inner['expires_at']?.toString()),
      receivedAt: DateTime.now(),
      createdAt: tryParseServerTimestamp(d['created_at']?.toString()),
      missionType: _str(inner['type']),
      missionId: nested ? _str(inner['id']) : null,
      triggerKind: _str(trigger['kind']) ?? 'manual',
      triggerTime: _str(trigger['time']),
      delayS: (trigger['delay_s'] as num?)?.toInt(),
      days: trigger['days'] is List
          ? (trigger['days'] as List).map((e) => e.toString()).toList()
          : const [],
      durationS: (inner['duration_s'] as num?)?.toInt(),
      rewardTreats: (inner['reward_treats'] as num?)?.toInt(),
      goal: _str(inner['goal']),
      warnings: d['warnings'] is List
          ? (d['warnings'] as List).map((e) => e.toString()).toList()
          : const [],
      status: _str(d['status']),
    );
  }

  static String? _str(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

enum DraftDecision { approve, decline }

/// One line of the agent transcript shown on the demo view. Relay WS
/// `agent_transcript` {dog_id, role: user|agent, text, ts}; the app also
/// appends local lines for drafts received / decided.
class AgentTranscriptLine {
  final DateTime ts;
  final String speaker; // assistant name, "You", "WIM-Z" (voice agent)
  final String role; // user | agent | assistant | tool | system
  final String text;
  final AiProvider? provider;
  final String? dogId;

  const AgentTranscriptLine({
    required this.ts,
    required this.speaker,
    required this.role,
    required this.text,
    this.provider,
    this.dogId,
  });

  bool get isUser => role == 'user';

  static AgentTranscriptLine? fromEvent(Map<String, dynamic> d) {
    final text = (d['text'] ?? d['message'] ?? d['content'])?.toString();
    if (text == null || text.isEmpty) return null;
    final provider = AiProvider.fromWire(
        (d['provider'] ?? d['assistant'])?.toString());
    final role = (d['role'] ?? 'agent').toString();
    return AgentTranscriptLine(
      ts: tryParseServerTimestamp((d['ts'] ?? d['timestamp'])?.toString()) ??
          DateTime.now(),
      speaker: d['assistant']?.toString() ??
          d['speaker']?.toString() ??
          provider?.displayName ??
          (role == 'user' ? 'Owner' : 'WIM-Z'),
      role: role,
      text: text,
      provider: provider,
      dogId: d['dog_id']?.toString(),
    );
  }
}
