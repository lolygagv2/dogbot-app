import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/ai_connection.dart';

/// Live agent transcript for the demo view. Collects WS `agent_transcript`
/// events (relay echoes what each connected assistant asked / did) plus
/// local lines appended by the app (draft received, approved, declined).
final agentTranscriptProvider = StateNotifierProvider<AgentTranscriptNotifier,
    List<AgentTranscriptLine>>((ref) {
  return AgentTranscriptNotifier(ref);
});

class AgentTranscriptNotifier extends StateNotifier<List<AgentTranscriptLine>> {
  static const _cap = 200;
  StreamSubscription? _sub;

  AgentTranscriptNotifier(Ref ref) : super(const []) {
    _sub = ref
        .read(websocketClientProvider)
        .eventStream
        .where((e) => e.type == 'agent_transcript' || e.type == 'agent_message')
        .listen((e) {
      final line = AgentTranscriptLine.fromEvent(e.data);
      if (line != null) append(line);
    });
  }

  /// Oldest first; the view scrolls to the end.
  void append(AgentTranscriptLine line) {
    final next = [...state, line];
    state = next.length > _cap ? next.sublist(next.length - _cap) : next;
  }

  void appendLocal(String speaker, String text, {String role = 'system'}) {
    append(AgentTranscriptLine(
      ts: DateTime.now(),
      speaker: speaker,
      role: role,
      text: text,
    ));
  }

  void clear() => state = const [];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
