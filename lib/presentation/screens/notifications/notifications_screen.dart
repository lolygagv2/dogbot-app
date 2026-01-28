import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_event.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../theme/app_theme.dart';

/// Notifications center screen showing chronological event feed
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Set<NotificationEventType>? _activeFilter;

  @override
  Widget build(BuildContext context) {
    final notifications = _activeFilter != null
        ? ref.watch(filteredNotificationsProvider(_activeFilter))
        : ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    // Group notifications by day
    final grouped = _groupByDay(notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              child: const Text('Mark all read'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'clear_all') {
                ref.read(notificationsProvider.notifier).clearAll();
                return;
              }
              setState(() {
                if (value == 'all') {
                  _activeFilter = null;
                } else {
                  _activeFilter = _getFilterSet(value);
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'behaviors', child: Text('Behaviors')),
              const PopupMenuItem(value: 'missions', child: Text('Missions')),
              const PopupMenuItem(value: 'alerts', child: Text('Alerts')),
              const PopupMenuItem(value: 'treats', child: Text('Treats')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear all', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  return _buildDaySection(entry.key, entry.value);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Events from WIM-Z will appear here',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(String dayLabel, List<NotificationEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            dayLabel,
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        ...events.map((event) => Dismissible(
              key: ValueKey(event.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                ref.read(notificationsProvider.notifier).removeNotification(event.id);
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: _NotificationTile(
                event: event,
                onTap: () => _handleNotificationTap(event),
              ),
            )),
      ],
    );
  }

  Map<String, List<NotificationEvent>> _groupByDay(
      List<NotificationEvent> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));

    final Map<String, List<NotificationEvent>> grouped = {};

    for (final notification in notifications) {
      final date = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );

      String label;
      if (date == today) {
        label = 'TODAY';
      } else if (date == yesterday) {
        label = 'YESTERDAY';
      } else if (date.isAfter(thisWeekStart)) {
        label = 'THIS WEEK';
      } else {
        label = 'EARLIER';
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(notification);
    }

    // Sort to maintain order: Today, Yesterday, This Week, Earlier
    final sortOrder = ['TODAY', 'YESTERDAY', 'THIS WEEK', 'EARLIER'];
    final sorted = Map.fromEntries(
      sortOrder
          .where((key) => grouped.containsKey(key))
          .map((key) => MapEntry(key, grouped[key]!)),
    );

    return sorted;
  }

  Set<NotificationEventType> _getFilterSet(String filter) {
    return switch (filter) {
      'behaviors' => {
          NotificationEventType.sit,
          NotificationEventType.lieDown,
          NotificationEventType.stand,
          NotificationEventType.bark,
          NotificationEventType.happy,
        },
      'missions' => {
          NotificationEventType.missionStarted,
          NotificationEventType.missionCompleted,
          NotificationEventType.missionFailed,
        },
      'alerts' => {
          NotificationEventType.lowBattery,
          NotificationEventType.alert,
          NotificationEventType.connected,
          NotificationEventType.disconnected,
        },
      'treats' => {
          NotificationEventType.treatDispensed,
        },
      _ => {},
    };
  }

  void _handleNotificationTap(NotificationEvent event) {
    // Mark as read
    ref.read(notificationsProvider.notifier).markAsRead(event.id);

    // Navigate to related screen based on type
    // TODO: Implement navigation to video clip, mission detail, etc.
  }
}

/// Individual notification tile widget
class _NotificationTile extends StatelessWidget {
  final NotificationEvent event;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon(event.type);
    final color = _getColor(event.type);

    return Material(
      color: event.isRead ? Colors.transparent : AppTheme.surfaceLight,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight:
                                  event.isRead ? FontWeight.normal : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(event.timestamp),
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Unread indicator
              if (!event.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => Icons.volume_up,
      NotificationEventType.sit => Icons.pets,
      NotificationEventType.lieDown => Icons.airline_seat_flat,
      NotificationEventType.stand => Icons.accessibility_new,
      NotificationEventType.treatDispensed => Icons.cookie,
      NotificationEventType.missionStarted => Icons.play_circle,
      NotificationEventType.missionCompleted => Icons.check_circle,
      NotificationEventType.missionFailed => Icons.cancel,
      NotificationEventType.lowBattery => Icons.battery_alert,
      NotificationEventType.alert => Icons.warning,
      NotificationEventType.happy => Icons.sentiment_very_satisfied,
      NotificationEventType.connected => Icons.wifi,
      NotificationEventType.disconnected => Icons.wifi_off,
    };
  }

  Color _getColor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => Colors.orange,
      NotificationEventType.sit => AppTheme.accent,
      NotificationEventType.lieDown => AppTheme.primary,
      NotificationEventType.stand => Colors.amber,
      NotificationEventType.treatDispensed => AppTheme.accent,
      NotificationEventType.missionStarted => AppTheme.primary,
      NotificationEventType.missionCompleted => AppTheme.accent,
      NotificationEventType.missionFailed => AppTheme.error,
      NotificationEventType.lowBattery => AppTheme.error,
      NotificationEventType.alert => Colors.orange,
      NotificationEventType.happy => AppTheme.accent,
      NotificationEventType.connected => AppTheme.accent,
      NotificationEventType.disconnected => AppTheme.error,
    };
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (date == today) {
      // Today - show time
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    } else {
      // Other days - show time
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    }
  }
}
