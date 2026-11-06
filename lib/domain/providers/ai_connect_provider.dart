import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/ai_connect_api.dart';
import '../../data/models/ai_connection.dart';
import '../../l10n/l10n.dart';
import 'auth_provider.dart';
import 'l10n_provider.dart';

/// Connected AI screen state: connector URL, assistants, kill switch, audit.
final aiConnectProvider =
    StateNotifierProvider<AiConnectNotifier, AiConnectionsState>(
        (ref) => AiConnectNotifier(ref));

class AiConnectNotifier extends StateNotifier<AiConnectionsState> {
  final Ref _ref;
  StreamSubscription? _sub;
  AppLocalizations get _l => _ref.read(l10nProvider);

  AiConnectNotifier(this._ref) : super(const AiConnectionsState()) {
    // Relay broadcasts when an assistant connects / is revoked elsewhere.
    _sub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'ai_connection_changed')
        .listen((_) => load());
  }

  String? get _token => _ref.read(authProvider).token;

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(loading: false, error: _l.aiErrSignedOut);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    final api = _ref.read(aiConnectApiProvider);
    try {
      final conn = await api.getConnections(token);
      final audit = await api.getAudit(token);
      if (!mounted) return;
      final list = conn['assistants'] ?? conn['connections'] ?? const [];
      state = AiConnectionsState(
        connectorUrl: (conn['connector_url'] ?? conn['url'])?.toString(),
        enabled: conn['enabled'] != false && conn['kill_switch'] != true,
        assistants: [
          if (list is List)
            for (final a in list)
              if (a is Map) AiAssistant.fromJson(a.cast<String, dynamic>()),
        ],
        audit: audit,
      );
      connTrace('ai-connect', 'loaded ${state.assistants.length} assistants, enabled=${state.enabled}');
    } on AiConnectUnsupported {
      if (!mounted) return;
      state = const AiConnectionsState(unsupported: true);
      connTrace('ai-connect', 'relay slice not deployed (404)');
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: _l.aiErrLoadFailed);
      connTrace('ai-connect-error', '$e');
    }
  }

  Future<bool> revoke(String id) async {
    final token = _token;
    if (token == null) return false;
    final before = state.assistants;
    // Optimistic remove; restore on failure.
    state = state.copyWith(
        assistants: before.where((a) => a.id != id).toList(), clearError: true);
    final ok = await _ref.read(aiConnectApiProvider).revoke(token, id);
    if (!mounted) return ok;
    if (!ok) {
      state = state.copyWith(assistants: before, error: _l.aiErrRevokeFailed);
    }
    return ok;
  }

  /// Kill switch: enabled=false refuses every assistant at the relay.
  Future<bool> setEnabled(bool enabled) async {
    final token = _token;
    if (token == null) return false;
    final before = state.enabled;
    state = state.copyWith(enabled: enabled, clearError: true);
    final ok = await _ref.read(aiConnectApiProvider).setEnabled(token, enabled);
    if (!mounted) return ok;
    if (!ok) {
      state = state.copyWith(enabled: before, error: _l.aiErrKillSwitchFailed);
    } else {
      connTrace('ai-connect', 'kill switch ${enabled ? 'released' : 'ENGAGED'}');
    }
    return ok;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
