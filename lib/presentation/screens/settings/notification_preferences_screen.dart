import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_event.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Per-event-type notification preferences.
/// 3-way control per event type: Off / In-app / In-app + Push.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l = context.l10n;

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
        title: Text(l.notifPrefsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l.notifPrefsResetDefaults,
            onPressed: () async {
              await notifier.resetNotificationChannels();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.notifPrefsResetDefaults)),
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
            title: Text(l.notifPrefsEnableLockScreen),
            subtitle: Text(l.notifPrefsMasterSubtitle),
            value: settings.notificationsEnabled,
            onChanged: notifier.setNotificationsEnabled,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.notifPrefsPerEventType,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l.notifPrefsLegend,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  String _label(AppLocalizations l) {
    switch (type) {
      case NotificationEventType.bark:
        return l.notifPrefsBarking;
      case NotificationEventType.sit:
        return l.notifPrefsSitDetected;
      case NotificationEventType.lieDown:
        return l.notifPrefsLayDownDetected;
      case NotificationEventType.stand:
        return l.notifPrefsComeStandDetected;
      case NotificationEventType.treatDispensed:
        return l.notifPrefsTreatDispensed;
      case NotificationEventType.missionStarted:
        return l.notifPrefsMissionStarted;
      case NotificationEventType.missionCompleted:
        return l.notifPrefsMissionCompleted;
      case NotificationEventType.missionFailed:
        return l.notifPrefsMissionFailed;
      case NotificationEventType.lowBattery:
        return l.notifPrefsLowBattery;
      case NotificationEventType.alert:
        return l.notifPrefsGuardianAlert;
      case NotificationEventType.happy:
        return l.notifPrefsHappyDog;
      case NotificationEventType.connected:
        return l.notifPrefsRobotConnected;
      case NotificationEventType.disconnected:
        return l.notifPrefsRobotDisconnected;
      case NotificationEventType.coachReward:
        return l.notifPrefsCoachReward;
      case NotificationEventType.panicAlert:
        return l.notifPrefsPanicAlert;
      case NotificationEventType.sgSummary:
        return l.notifPrefsSgSummary;
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
      case NotificationEventType.panicAlert:
        return Icons.crisis_alert;
      case NotificationEventType.sgSummary:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
                _label(l),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedButton<NotificationChannel>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: NotificationChannel.off,
                label: Text(l.off),
                icon: const Icon(Icons.do_not_disturb_on, size: 16),
              ),
              ButtonSegment(
                value: NotificationChannel.inApp,
                label: Text(l.notifPrefsInApp),
                icon: const Icon(Icons.list_alt, size: 16),
              ),
              ButtonSegment(
                value: NotificationChannel.inAppAndPush,
                label: Text(l.notifPrefsPlusPush),
                icon: const Icon(Icons.notifications_active, size: 16),
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
