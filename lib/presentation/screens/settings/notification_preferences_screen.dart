import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_event.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Per-event-type notification preferences.
/// 3-way control per event type: Off / In-app / In-app + Push.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Order types so the most actionable ones appear first.
    const ordered = <NotificationEventType>[
      NotificationEventType.treatDispensed,
      NotificationEventType.coachReward,
      NotificationEventType.missionCompleted,
      NotificationEventType.missionFailed,
      NotificationEventType.alert,
      NotificationEventType.lowBattery,
      NotificationEventType.bark,
      NotificationEventType.happy,
      NotificationEventType.sit,
      NotificationEventType.lieDown,
      NotificationEventType.stand,
      NotificationEventType.missionStarted,
      NotificationEventType.connected,
      NotificationEventType.disconnected,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
            onPressed: () async {
              await notifier.resetNotificationChannels();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset to defaults')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Master switch — gates OS push entirely
          SwitchListTile(
            title: const Text('Enable lock-screen notifications'),
            subtitle: const Text(
                'Master switch. When off, nothing pushes to the lock screen or Apple Watch — events still appear in the in-app feed.'),
            value: settings.notificationsEnabled,
            onChanged: notifier.setNotificationsEnabled,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Per event type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Off — never recorded.\n'
              'In-app — appears in the activity feed only.\n'
              'In-app + Push — also wakes lock screen and Apple Watch.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          for (final type in ordered)
            _ChannelRow(
              type: type,
              channel: settings.channelFor(type),
              onChanged: (c) => notifier.setNotificationChannel(type, c),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final NotificationEventType type;
  final NotificationChannel channel;
  final ValueChanged<NotificationChannel> onChanged;

  const _ChannelRow({
    required this.type,
    required this.channel,
    required this.onChanged,
  });

  String get _label {
    switch (type) {
      case NotificationEventType.bark:
        return 'Barking';
      case NotificationEventType.sit:
        return 'Sit detected';
      case NotificationEventType.lieDown:
        return 'Lay down detected';
      case NotificationEventType.stand:
        return 'Come / stand detected';
      case NotificationEventType.treatDispensed:
        return 'Treat dispensed';
      case NotificationEventType.missionStarted:
        return 'Mission started';
      case NotificationEventType.missionCompleted:
        return 'Mission completed';
      case NotificationEventType.missionFailed:
        return 'Mission failed';
      case NotificationEventType.lowBattery:
        return 'Low battery';
      case NotificationEventType.alert:
        return 'Guardian alert';
      case NotificationEventType.happy:
        return 'Happy dog';
      case NotificationEventType.connected:
        return 'Robot connected';
      case NotificationEventType.disconnected:
        return 'Robot disconnected';
      case NotificationEventType.coachReward:
        return 'Coach reward';
    }
  }

  IconData get _icon {
    switch (type) {
      case NotificationEventType.bark:
        return Icons.campaign;
      case NotificationEventType.treatDispensed:
        return Icons.cookie;
      case NotificationEventType.coachReward:
        return Icons.celebration;
      case NotificationEventType.missionCompleted:
      case NotificationEventType.missionFailed:
      case NotificationEventType.missionStarted:
        return Icons.flag;
      case NotificationEventType.lowBattery:
        return Icons.battery_alert;
      case NotificationEventType.alert:
        return Icons.warning_amber;
      case NotificationEventType.happy:
        return Icons.mood;
      case NotificationEventType.connected:
        return Icons.cloud_done;
      case NotificationEventType.disconnected:
        return Icons.cloud_off;
      case NotificationEventType.sit:
      case NotificationEventType.lieDown:
      case NotificationEventType.stand:
        return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                _label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedButton<NotificationChannel>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: NotificationChannel.off,
                label: Text('Off'),
                icon: Icon(Icons.do_not_disturb_on, size: 16),
              ),
              ButtonSegment(
                value: NotificationChannel.inApp,
                label: Text('In-app'),
                icon: Icon(Icons.list_alt, size: 16),
              ),
              ButtonSegment(
                value: NotificationChannel.inAppAndPush,
                label: Text('+ Push'),
                icon: Icon(Icons.notifications_active, size: 16),
              ),
            ],
            selected: {channel},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onChanged(s.first);
            },
          ),
        ],
      ),
    );
  }
}
