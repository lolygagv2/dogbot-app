import '../../core/utils/time_utils.dart';

/// Connected AI — assistants (ChatGPT, Claude, Grok, Perplexity) that reach
/// WIM-Z through the relay's connector endpoint. Contract:
/// `.claude/APP_CONTRACT_AI_SUMMIT_DEMO_2026-11-05.md` §2.

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

class AiAssistant {
  final String id;
  final String name;
  final AiProvider? provider;
  final List<String> scopes;
  final DateTime? connectedAt;
  final DateTime? lastUsedAt;

  const AiAssistant({
    required this.id,
    required this.name,
    this.provider,
    this.scopes = const [],
    this.connectedAt,
    this.lastUsedAt,
  });

  static AiAssistant fromJson(Map<String, dynamic> j) {
    final provider =
        AiProvider.fromWire(j['provider']?.toString() ?? j['name']?.toString());
    return AiAssistant(
      id: (j['id'] ?? j['connection_id'] ?? j['client_id'] ?? '').toString(),
      name: j['name']?.toString() ??
          provider?.displayName ??
          j['client_id']?.toString() ??
          'Assistant',
      provider: provider,
      scopes: j['scopes'] is List
          ? (j['scopes'] as List).map((s) => s.toString()).toList()
          : (j['scope'] is String
              ? (j['scope'] as String).split(RegExp(r'[ ,]+'))
              : const []),
      connectedAt: tryParseServerTimestamp(j['connected_at']?.toString()),
      lastUsedAt: tryParseServerTimestamp(j['last_used_at']?.toString()),
    );
  }
}

class AiAuditEntry {
  final String id;
  final DateTime ts;
  final String assistant;
  final AiProvider? provider;
  final String action;
  final String? scope;
  final String result; // ok | denied | error
  final String? detail;

  const AiAuditEntry({
    required this.id,
    required this.ts,
    required this.assistant,
    this.provider,
    required this.action,
    this.scope,
    this.result = 'ok',
    this.detail,
  });

  bool get isOk => result == 'ok' || result == 'success';

  static AiAuditEntry fromJson(Map<String, dynamic> j) {
    final provider = AiProvider.fromWire(
        j['provider']?.toString() ?? j['assistant']?.toString());
    return AiAuditEntry(
      id: (j['id'] ?? j['ts'] ?? j['timestamp'] ?? '').toString(),
      ts: parseServerTimestamp((j['ts'] ?? j['timestamp'])?.toString()),
      assistant: j['assistant']?.toString() ??
          j['name']?.toString() ??
          provider?.displayName ??
          '?',
      provider: provider,
      action: (j['action'] ?? j['tool'] ?? j['event'] ?? '').toString(),
      scope: j['scope']?.toString(),
      result: (j['result'] ?? j['status'] ?? 'ok').toString().toLowerCase(),
      detail: j['detail']?.toString() ?? j['summary']?.toString(),
    );
  }
}

/// Everything the Connected AI screen shows, from GET /api/ai/connections
/// (+ GET /api/ai/audit).
class AiConnectionsState {
  final String? connectorUrl;

  /// False = kill switch engaged: every assistant is refused at the relay.
  final bool enabled;
  final List<AiAssistant> assistants;
  final List<AiAuditEntry> audit;
  final bool loading;
  final String? error;

  /// True when the relay answered 404 — the slice isn't deployed yet.
  final bool unsupported;

  const AiConnectionsState({
    this.connectorUrl,
    this.enabled = true,
    this.assistants = const [],
    this.audit = const [],
    this.loading = false,
    this.error,
    this.unsupported = false,
  });

  AiConnectionsState copyWith({
    String? connectorUrl,
    bool? enabled,
    List<AiAssistant>? assistants,
    List<AiAuditEntry>? audit,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? unsupported,
  }) {
    return AiConnectionsState(
      connectorUrl: connectorUrl ?? this.connectorUrl,
      enabled: enabled ?? this.enabled,
      assistants: assistants ?? this.assistants,
      audit: audit ?? this.audit,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      unsupported: unsupported ?? this.unsupported,
    );
  }
}

/// A mission an assistant drafted and is asking the owner to approve.
/// Arrives as WS event `mission_draft`; decided via
/// POST /api/ai/drafts/{id}/decision (WS fallback `mission_draft_decision`).
class MissionDraft {
  final String id;
  final String title;
  final String? summary;
  final List<String> steps;
  final String? proposedBy; // assistant display name
  final AiProvider? provider;
  final String? dogId;
  final String? dogName;
  final DateTime? expiresAt;
  final DateTime receivedAt;

  const MissionDraft({
    required this.id,
    required this.title,
    this.summary,
    this.steps = const [],
    this.proposedBy,
    this.provider,
    this.dogId,
    this.dogName,
    this.expiresAt,
    required this.receivedAt,
  });

  static MissionDraft? fromEvent(Map<String, dynamic> d) {
    final inner = d['draft'] is Map ? (d['draft'] as Map).cast<String, dynamic>() : d;
    final id = (inner['draft_id'] ?? inner['id'] ?? d['draft_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    final title = (inner['title'] ?? inner['name'] ?? inner['mission_name'])
            ?.toString() ??
        'Mission';
    final provider = AiProvider.fromWire(
        (inner['provider'] ?? inner['proposed_by'] ?? d['provider'])?.toString());
    return MissionDraft(
      id: id,
      title: title,
      summary: (inner['summary'] ?? inner['description'])?.toString(),
      steps: inner['steps'] is List
          ? (inner['steps'] as List)
              .map((s) => s is Map ? (s['text'] ?? s['name'] ?? '').toString() : s.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
      proposedBy: (inner['proposed_by'] ?? inner['assistant'] ?? d['assistant'])
              ?.toString() ??
          provider?.displayName,
      provider: provider,
      dogId: (inner['dog_id'] ?? d['dog_id'])?.toString(),
      dogName: (inner['dog_name'] ?? d['dog_name'])?.toString(),
      expiresAt: tryParseServerTimestamp(inner['expires_at']?.toString()),
      receivedAt: DateTime.now(),
    );
  }
}

enum DraftDecision { approve, decline }

/// One line of the agent transcript shown on the demo view. WS event
/// `agent_transcript` {assistant, provider, role, text, ts}; the app also
/// appends local lines for drafts received / decided.
class AgentTranscriptLine {
  final DateTime ts;
  final String speaker; // assistant name, "You", or "WIM-Z"
  final String role; // user | assistant | tool | system
  final String text;
  final AiProvider? provider;

  const AgentTranscriptLine({
    required this.ts,
    required this.speaker,
    required this.role,
    required this.text,
    this.provider,
  });

  static AgentTranscriptLine? fromEvent(Map<String, dynamic> d) {
    final text = (d['text'] ?? d['message'] ?? d['content'])?.toString();
    if (text == null || text.isEmpty) return null;
    final provider = AiProvider.fromWire(
        (d['provider'] ?? d['assistant'])?.toString());
    final role = (d['role'] ?? 'assistant').toString();
    return AgentTranscriptLine(
      ts: tryParseServerTimestamp((d['ts'] ?? d['timestamp'])?.toString()) ??
          DateTime.now(),
      speaker: d['assistant']?.toString() ??
          d['speaker']?.toString() ??
          provider?.displayName ??
          (role == 'user' ? 'Owner' : 'Assistant'),
      role: role,
      text: text,
      provider: provider,
    );
  }
}
