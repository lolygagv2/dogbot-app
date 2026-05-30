import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/guardian_event.dart';
import 'connection_provider.dart';
import 'mode_provider.dart';

/// Maximum number of events to keep in memory
const int _maxEvents = 100;

/// State for guardian events
class GuardianEventsState {
  final List<GuardianEvent> events;
  final int unreadCount;
  final bool isListening;

  const GuardianEventsState({
    this.events = const [],
    this.unreadCount = 0,
    this.isListening = false,
  });

  GuardianEventsState copyWith({
    List<GuardianEvent>? events,
    int? unreadCount,
    bool? isListening,
  }) {
    return GuardianEventsState(
      events: events ?? this.events,
      unreadCount: unreadCount ?? this.unreadCount,
      isListening: isListening ?? this.isListening,
    );
  }

  /// Get events sorted by timestamp (newest first)
  List<GuardianEvent> get sortedEvents {
    final sorted = List<GuardianEvent>.from(events);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }
}

/// Provider for guardian events state
final guardianEventsProvider =
    StateNotifierProvider<GuardianEventsNotifier, GuardianEventsState>((ref) {
  return GuardianEventsNotifier(ref);
});

/// Notifier for managing guardian events
class GuardianEventsNotifier extends StateNotifier<GuardianEventsState> {
  final Ref _ref;
  StreamSubscription<WsEvent>? _wsSubscription;

  GuardianEventsNotifier(this._ref) : super(const GuardianEventsState()) {
    // Stay subscribed across the connection lifecycle (like notificationsProvider)
    // so store-and-forward replays — which arrive on WS (re)connect, before the
    // user opens the guardian screen — are captured rather than missed. The
    // screen still calls startListening(); it's idempotent (isListening guard).
    _ref.listen<ConnectionState>(connectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        startListening();
      } else if (!next.isConnected) {
        stopListening();
      }
    });
    if (_ref.read(connectionProvider).isConnected) {
      startListening();
    }
  }

  /// Start listening for guardian events from WebSocket
  void startListening() {
    if (state.isListening) return;

    final ws = _ref.read(websocketClientProvider);
    _wsSubscription?.cancel();
    _wsSubscription = ws.eventStream.listen(_handleWsEvent);

    state = state.copyWith(isListening: true);
    print('GuardianEvents: Started listening for events');
  }

  /// Stop listening for events
  void stopListening() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    state = state.copyWith(isListening: false);
    print('GuardianEvents: Stopped listening for events');
  }

  /// Handle incoming WebSocket events
  void _handleWsEvent(WsEvent wsEvent) {
    // Live events are only relevant in Silent Guardian mode, but ALWAYS ingest
    // buffered (store-and-forward) replays — they're the offline SG backlog and
    // arrive regardless of the mode the app is in on reconnect.
    final currentMode = _ref.read(modeStateProvider).currentMode;
    if (!wsEvent.buffered && currentMode != RobotMode.silentGuardian) return;

    // Look for guardian/event type messages
    if (wsEvent.type == 'event' ||
        wsEvent.type == 'guardian_event' ||
        wsEvent.data.containsKey('event_type')) {

      try {
        // Prefer the relay's authoritative server time and stable id (top-level
        // envelope fields) over anything inside the payload, so replays land at
        // their real moment.
        final data = {
          ...wsEvent.data,
          if (wsEvent.tsServer != null) 'timestamp': wsEvent.tsServer,
          if (wsEvent.id != null) 'id': wsEvent.id,
        };
        final event = GuardianEvent.fromJson(data);
        _addEvent(event);
        print('GuardianEvents: Received ${event.type.label}');
      } catch (e) {
        print('GuardianEvents: Failed to parse event: $e');
      }
    }
  }

  /// Add a new event to the list
  void _addEvent(GuardianEvent event) {
    final newEvents = [event, ...state.events];

    // Trim to max events
    final trimmedEvents = newEvents.length > _maxEvents
        ? newEvents.sublist(0, _maxEvents)
        : newEvents;

    state = state.copyWith(
      events: trimmedEvents,
      unreadCount: state.unreadCount + 1,
    );
  }

  /// Mark all events as read (reset unread count)
  void markAllRead() {
    state = state.copyWith(unreadCount: 0);
  }

  /// Clear all events
  void clearEvents() {
    state = state.copyWith(
      events: [],
      unreadCount: 0,
    );
  }

  /// Add a test event (for debugging)
  void addTestEvent(GuardianEventType type, String? details) {
    final event = GuardianEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      details: details,
    );
    _addEvent(event);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for unread event count (for badges)
final unreadEventCountProvider = Provider<int>((ref) {
  return ref.watch(guardianEventsProvider).unreadCount;
});
