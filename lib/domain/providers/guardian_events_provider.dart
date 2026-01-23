import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/guardian_event.dart';

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

  GuardianEventsNotifier(this._ref) : super(const GuardianEventsState());

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
    // Look for guardian/event type messages
    if (wsEvent.type == 'event' ||
        wsEvent.type == 'guardian_event' ||
        wsEvent.data.containsKey('event_type')) {

      try {
        final event = GuardianEvent.fromJson(wsEvent.data);
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
