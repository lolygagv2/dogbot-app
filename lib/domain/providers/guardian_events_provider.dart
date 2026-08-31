import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/guardian_event.dart';
import '../../data/models/notification_event.dart';
import 'notifications_provider.dart';

/// Maximum number of events to keep in the projected feed
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

/// Provider for guardian events state.
///
/// Build 125: this is now a PROJECTION of the single source of truth
/// (`notificationsProvider`), not a separate WebSocket-only list. Unifying the
/// two lists fixes the "two-list rot": the SG feed now gets the same live WS
/// events, the same relay REST history (hydrate on open + resume), and the same
/// store-and-forward replay that the Activity tab gets — so opening the app
/// hours later shows the real backlog here too.
final guardianEventsProvider =
    StateNotifierProvider<GuardianEventsNotifier, GuardianEventsState>((ref) {
  return GuardianEventsNotifier(ref);
});

/// Notifier projecting notification events into the guardian feed.
class GuardianEventsNotifier extends StateNotifier<GuardianEventsState> {
  final Ref _ref;

  GuardianEventsNotifier(this._ref) : super(const GuardianEventsState()) {
    // Recompute whenever the single source changes.
    _ref.listen<List<NotificationEvent>>(notificationsProvider, (_, next) {
      _recompute(next);
    });
    _recompute(_ref.read(notificationsProvider));
  }

  /// Map a notification to a guardian event, or null if it isn't a
  /// guardian-relevant type (missions, battery, connect/disconnect are excluded
  /// from the SG feed but still live in the Activity tab).
  GuardianEvent? _toGuardianEvent(NotificationEvent n) {
    final type = switch (n.type) {
      NotificationEventType.bark => GuardianEventType.barkingDetected,
      NotificationEventType.sit ||
      NotificationEventType.lieDown ||
      NotificationEventType.stand ||
      NotificationEventType.happy =>
        GuardianEventType.behaviorChange,
      NotificationEventType.treatDispensed => GuardianEventType.treatDispensed,
      NotificationEventType.coachReward => GuardianEventType.quietReward,
      NotificationEventType.alert => GuardianEventType.alertTriggered,
      // Robot 137a5e8: panic episodes + level-4/session summaries belong in
      // the SG feed (the live summary card shows current state; these are
      // the historical entries).
      NotificationEventType.panicAlert => GuardianEventType.alertTriggered,
      NotificationEventType.sgSummary => GuardianEventType.alertTriggered,
      _ => null,
    };
    if (type == null) return null;
    return GuardianEvent(
      id: n.id,
      type: type,
      timestamp: n.timestamp,
      details: n.subtitle,
      metadata: n.metadata,
    );
  }

  void _recompute(List<NotificationEvent> notifications) {
    final events = <GuardianEvent>[];
    var unread = 0;
    for (final n in notifications) {
      final g = _toGuardianEvent(n);
      if (g == null) continue;
      events.add(g);
      if (!n.isRead) unread++;
    }
    final trimmed =
        events.length > _maxEvents ? events.sublist(0, _maxEvents) : events;
    state = state.copyWith(events: trimmed, unreadCount: unread);
  }

  /// Kept for widget API compatibility — ingestion is global now, so these are
  /// no-ops (the projection already tracks the single source).
  void startListening() {
    if (!state.isListening) state = state.copyWith(isListening: true);
  }

  void stopListening() {
    if (state.isListening) state = state.copyWith(isListening: false);
  }

  /// Mark guardian events as read by clearing the unread badge. Delegates to
  /// the single source so the Activity tab stays consistent.
  void markAllRead() {
    _ref.read(notificationsProvider.notifier).markAllAsRead();
    state = state.copyWith(unreadCount: 0);
  }

  /// Clear the feed — clears the single source (Activity tab clears too).
  void clearEvents() {
    _ref.read(notificationsProvider.notifier).clearAll();
  }
}

/// Provider for unread event count (for badges)
final unreadEventCountProvider = Provider<int>((ref) {
  return ref.watch(guardianEventsProvider).unreadCount;
});
