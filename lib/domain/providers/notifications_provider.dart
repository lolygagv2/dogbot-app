import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/models/notification_event.dart';
import 'connection_provider.dart';

/// Provider for notification events list
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationEvent>>((ref) {
  return NotificationsNotifier(ref);
});

/// Provider for unread notification count
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

/// Provider to filter notifications by type
final filteredNotificationsProvider =
    Provider.family<List<NotificationEvent>, Set<NotificationEventType>?>(
        (ref, filter) {
  final notifications = ref.watch(notificationsProvider);
  if (filter == null || filter.isEmpty) return notifications;
  return notifications.where((n) => filter.contains(n.type)).toList();
});

/// Notifications state notifier
class NotificationsNotifier extends StateNotifier<List<NotificationEvent>> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;

  NotificationsNotifier(this._ref) : super(_generateMockData()) {
    // Listen for WebSocket events to add real notifications
    _ref.listen<ConnectionState>(connectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        _startListening();
      } else if (!next.isConnected) {
        _stopListening();
      }
    });

    if (_ref.read(connectionProvider).isConnected) {
      _startListening();
    }
  }

  void _startListening() {
    _wsSubscription?.cancel();
    _wsSubscription =
        _ref.read(websocketClientProvider).eventStream.listen(_handleWsEvent);
  }

  void _stopListening() {
    _wsSubscription?.cancel();
  }

  void _handleWsEvent(WsEvent event) {
    // Convert WebSocket events to notifications
    NotificationEvent? notification;

    switch (event.type) {
      case 'detection':
        final behavior = event.data['behavior'] as String?;
        if (behavior != null) {
          notification = _createBehaviorNotification(behavior, event.data);
        }
        break;

      case 'treat':
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.treatDispensed,
          timestamp: DateTime.now(),
          title: 'Treat Dispensed',
          subtitle: 'Good job!',
        );
        break;

      case 'mission_start':
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.missionStarted,
          timestamp: DateTime.now(),
          title: 'Mission Started',
          subtitle: event.data['name'] as String?,
          missionId: event.data['id'] as String?,
        );
        break;

      case 'mission_complete':
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.missionCompleted,
          timestamp: DateTime.now(),
          title: 'Mission Completed',
          subtitle: event.data['name'] as String?,
          missionId: event.data['id'] as String?,
        );
        break;

      case 'battery':
        final level = (event.data['level'] as num?)?.toDouble() ?? 100;
        if (level < 20) {
          notification = NotificationEvent(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: NotificationEventType.lowBattery,
            timestamp: DateTime.now(),
            title: 'Low Battery',
            subtitle: '${level.toInt()}% remaining',
          );
        }
        break;
    }

    if (notification != null) {
      addNotification(notification);
    }
  }

  NotificationEvent? _createBehaviorNotification(
      String behavior, Map<String, dynamic> data) {
    final type = switch (behavior.toLowerCase()) {
      'sit' || 'sitting' => NotificationEventType.sit,
      'lie' || 'lying' || 'down' || 'lie_down' => NotificationEventType.lieDown,
      'stand' || 'standing' => NotificationEventType.stand,
      'bark' || 'barking' => NotificationEventType.bark,
      _ => null,
    };

    if (type == null) return null;

    final confidence = (data['confidence'] as num?)?.toDouble();
    final confidenceStr =
        confidence != null ? '${(confidence * 100).toInt()}% confidence' : null;

    return NotificationEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      title: _getDefaultTitle(type),
      subtitle: confidenceStr,
      dogId: data['dog_id'] as String?,
    );
  }

  String _getDefaultTitle(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => 'Barking Detected',
      NotificationEventType.sit => 'Sitting Detected',
      NotificationEventType.lieDown => 'Lying Down',
      NotificationEventType.stand => 'Standing',
      NotificationEventType.treatDispensed => 'Treat Dispensed',
      NotificationEventType.missionStarted => 'Mission Started',
      NotificationEventType.missionCompleted => 'Mission Completed',
      NotificationEventType.missionFailed => 'Mission Failed',
      NotificationEventType.lowBattery => 'Low Battery',
      NotificationEventType.alert => 'Alert',
      NotificationEventType.happy => 'Happy Dog',
      NotificationEventType.connected => 'Connected',
      NotificationEventType.disconnected => 'Disconnected',
    };
  }

  /// Add a new notification to the list
  void addNotification(NotificationEvent notification) {
    state = [notification, ...state];
    // Keep only the last 100 notifications
    if (state.length > 100) {
      state = state.sublist(0, 100);
    }
  }

  /// Mark a notification as read
  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  /// Clear all notifications
  void clearAll() {
    state = [];
  }

  /// Refresh notifications (would fetch from API in real implementation)
  Future<void> refresh() async {
    // In a real implementation, fetch from API
    // For now, just use the existing state
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}

/// Generate mock notification data for testing
List<NotificationEvent> _generateMockData() {
  final now = DateTime.now();
  return [
    // Today
    NotificationEvent(
      id: '1',
      type: NotificationEventType.treatDispensed,
      timestamp: now.subtract(const Duration(minutes: 5)),
      title: 'Treat Dispensed',
      subtitle: 'Max earned a reward for sitting',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '2',
      type: NotificationEventType.sit,
      timestamp: now.subtract(const Duration(minutes: 6)),
      title: 'Sitting Detected',
      subtitle: '94% confidence',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '3',
      type: NotificationEventType.bark,
      timestamp: now.subtract(const Duration(hours: 1)),
      title: 'Barking Alert',
      subtitle: '3 barks detected',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '4',
      type: NotificationEventType.happy,
      timestamp: now.subtract(const Duration(hours: 2)),
      title: 'Happy Dog',
      subtitle: 'Positive behavior detected',
      dogId: 'dog_1',
    ),
    // Yesterday
    NotificationEvent(
      id: '5',
      type: NotificationEventType.missionCompleted,
      timestamp: now.subtract(const Duration(days: 1, hours: 2)),
      title: 'Mission Completed',
      subtitle: '"Sit Training" - 5/5 treats',
      missionId: 'mission_1',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '6',
      type: NotificationEventType.missionStarted,
      timestamp: now.subtract(const Duration(days: 1, hours: 2, minutes: 30)),
      title: 'Mission Started',
      subtitle: '"Sit Training"',
      missionId: 'mission_1',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '7',
      type: NotificationEventType.treatDispensed,
      timestamp: now.subtract(const Duration(days: 1, hours: 4)),
      title: 'Treat Dispensed',
      subtitle: 'Manual treat given',
    ),
    NotificationEvent(
      id: '8',
      type: NotificationEventType.lowBattery,
      timestamp: now.subtract(const Duration(days: 1, hours: 6)),
      title: 'Low Battery',
      subtitle: '15% remaining',
    ),
    // This week
    NotificationEvent(
      id: '9',
      type: NotificationEventType.connected,
      timestamp: now.subtract(const Duration(days: 2)),
      title: 'Connected',
      subtitle: 'WIM-Z came online',
    ),
    NotificationEvent(
      id: '10',
      type: NotificationEventType.disconnected,
      timestamp: now.subtract(const Duration(days: 2, hours: 1)),
      title: 'Disconnected',
      subtitle: 'WIM-Z went offline',
    ),
    NotificationEvent(
      id: '11',
      type: NotificationEventType.missionFailed,
      timestamp: now.subtract(const Duration(days: 3)),
      title: 'Mission Failed',
      subtitle: '"Quiet Training" - Timeout',
      missionId: 'mission_2',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '12',
      type: NotificationEventType.lieDown,
      timestamp: now.subtract(const Duration(days: 4)),
      title: 'Lying Down',
      subtitle: '87% confidence',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '13',
      type: NotificationEventType.stand,
      timestamp: now.subtract(const Duration(days: 5)),
      title: 'Standing',
      subtitle: '91% confidence',
      dogId: 'dog_1',
    ),
    NotificationEvent(
      id: '14',
      type: NotificationEventType.alert,
      timestamp: now.subtract(const Duration(days: 6)),
      title: 'Alert',
      subtitle: 'Unknown movement detected',
    ),
  ];
}
