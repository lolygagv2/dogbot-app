import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_event.dart';
import '../../../domain/providers/analytics_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/notifications_provider.dart';
import '../../theme/app_theme.dart';
import 'activity_dashboard.dart';

/// Activity screen with Dashboard and Events tabs
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<NotificationEventType>? _activeFilter;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(activityTabIndexProvider);
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(activityTabIndexProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);
    final selectedDog = ref.watch(selectedDogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          // Events tab actions only
          if (_tabController.index == 1 && unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              child: const Text('Mark all read'),
            ),
          if (_tabController.index == 1)
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
                const PopupMenuItem(value: 'coach', child: Text('Coach')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}), // rebuild actions
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textTertiary,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 20), text: 'Dashboard'),
            Tab(icon: Icon(Icons.notifications, size: 20), text: 'Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ActivityDashboard(dogId: selectedDog?.id),
          _EventsTab(
            activeFilter: _activeFilter,
          ),
        ],
      ),
    );
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
      'coach' => {
          NotificationEventType.coachReward,
        },
      _ => {},
    };
  }
}

/// Events tab — the original notifications list
class _EventsTab extends ConsumerWidget {
  final Set<NotificationEventType>? activeFilter;

  const _EventsTab({this.activeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = activeFilter != null
        ? ref.watch(filteredNotificationsProvider(activeFilter))
        : ref.watch(notificationsProvider);

    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = _groupByDay(notifications);

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          return _buildDaySection(context, ref, entry.key, entry.value);
        },
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

  Widget _buildDaySection(
    BuildContext context,
    WidgetRef ref,
    String dayLabel,
    List<NotificationEvent> events,
  ) {
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
                onTap: () {
                  ref.read(notificationsProvider.notifier).markAsRead(event.id);
                },
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

    final sortOrder = ['TODAY', 'YESTERDAY', 'THIS WEEK', 'EARLIER'];
    final sorted = Map.fromEntries(
      sortOrder
          .where((key) => grouped.containsKey(key))
          .map((key) => MapEntry(key, grouped[key]!)),
    );

    return sorted;
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
      NotificationEventType.coachReward => Icons.school,
      NotificationEventType.panicAlert => Icons.crisis_alert,
      NotificationEventType.sgSummary => Icons.shield_outlined,
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
      NotificationEventType.coachReward => Colors.orange,
      NotificationEventType.panicAlert => AppTheme.error,
      NotificationEventType.sgSummary => Colors.purple,
    };
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatTime(DateTime timestamp) {
    // Defensive: any UTC-parsed instant renders in device-local time.
    timestamp = timestamp.toLocal();
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${_months[timestamp.month - 1]} ${timestamp.day}, $hour12:$minute $period';
  }
}
