import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../data/datasources/ai_connect_api.dart';
import '../../data/models/ai_connection.dart';
import '../../l10n/l10n.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';
import 'l10n_provider.dart';

/// Connected AI screen state: connector URL, assistants, audit, and the
/// "disconnect all" action (relay `revoke_all` — its kill switch).
final aiConnectProvider =
    StateNotifierProvider<AiConnectNotifier, AiConnectionsState>(
        (ref) => AiConnectNotifier(ref));

class AiConnectNotifier extends StateNotifier<AiConnectionsState> {
  final Ref _ref;
  StreamSubscription? _sub;
  AppLocalizations get _l => _ref.read(l10nProvider);

  AiConnectNotifier(this._ref) : super(const AiConnectionsState()) {
    // Optional relay broadcast when an assistant connects / is revoked
    // elsewhere (not in the 2026-11-06 brief; harmless if never sent).
    _sub = _ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'ai_connection_changed')
        .listen((_) => load());
    // Relay routes are dog-scoped: reload when the selected dog changes.
    _ref.listen<String?>(
      selectedDogProvider.select((d) => d?.id),
      (prev, next) {
        if (prev != next && next != null && state.dogId != null) load();
      },
    );
  }

  String? get _token => _ref.read(authProvider).token;
  String? get _dogId => _ref.read(selectedDogProvider)?.id;

  /// client_name for a connector client_id, when the list is loaded.
  String? nameForClient(String? clientId) {
    if (clientId == null) return null;
    for (final a in state.assistants) {
      if (a.id == clientId) return a.name;
    }
    return null;
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(loading: false, error: _l.aiErrSignedOut);
      return;
    }
    final dogId = _dogId;
    if (dogId == null) {
      state = state.copyWith(loading: false, error: _l.aiErrNoDog);
      return;
    }
    state = state.copyWith(loading: true, clearError: true, dogId: dogId);
    final api = _ref.read(aiConnectApiProvider);
    try {
      final conn = await api.getConnectors(token, dogId);
      final audit = await api.getAudit(token, dogId);
      if (!mounted) return;
      final list = conn['assistants'] ?? conn['connections'] ?? const [];
      state = AiConnectionsState(
        dogId: dogId,
        connectorUrl: (conn['connector_url'] ?? conn['url'])?.toString(),
        assistants: [
          if (list is List)
            for (final a in list)
              if (a is Map) AiAssistant.fromJson(a.cast<String, dynamic>()),
        ],
        audit: audit,
      );
      connTrace('ai-connect',
          'dog=$dogId ${state.assistants.length} assistants, ${audit.length} audit rows');
    } on AiConnectUnsupported {
      if (!mounted) return;
      state = AiConnectionsState(unsupported: true, dogId: dogId);
      connTrace('ai-connect', 'relay slice not deployed (404)');
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: _l.aiErrLoadFailed);
      connTrace('ai-connect-error', '$e');
    }
  }

  Future<bool> revoke(String clientId) async {
    final token = _token;
    final dogId = state.dogId ?? _dogId;
    if (token == null || dogId == null) return false;
    final before = state.assistants;
    // Optimistic remove; restore on failure.
    state = state.copyWith(
        assistants: before.where((a) => a.id != clientId).toList(),
        clearError: true);
    final ok =
        await _ref.read(aiConnectApiProvider).revoke(token, dogId, clientId);
    if (!mounted) return ok;
    if (!ok) {
      state = state.copyWith(assistants: before, error: _l.aiErrRevokeFailed);
    } else {
      connTrace('ai-connect', 'revoked $clientId');
    }
    return ok;
  }

  /// Relay kill switch: revoke every assistant's tokens at once. Returns the
  /// number of tokens revoked, or null on failure.
  Future<int?> revokeAll() async {
    final token = _token;
    final dogId = state.dogId ?? _dogId;
    if (token == null || dogId == null) return null;
    state = state.copyWith(revokingAll: true, clearError: true);
    final n = await _ref.read(aiConnectApiProvider).revokeAll(token, dogId);
    if (!mounted) return n;
    if (n == null) {
      state = state.copyWith(revokingAll: false, error: _l.aiErrRevokeAllFailed);
    } else {
      state = state.copyWith(revokingAll: false, assistants: const []);
      connTrace('ai-connect', 'REVOKED ALL ($n tokens)');
    }
    return n;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
