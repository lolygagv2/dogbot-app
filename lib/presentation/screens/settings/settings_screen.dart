import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/paired_devices_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/push_to_talk_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../../domain/providers/video_quality_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import '../../../domain/providers/wifi_config_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_mode/night_vision_settings_section.dart';
import '../../widgets/silent_guardian/intervention_level_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load paired devices on screen open (skip in local mode — no relay API)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isLocal = ref.read(settingsProvider).localModeEnabled;
      if (!isLocal) {
        ref.read(pairedDevicesProvider.notifier).loadDevices();
      }
    });
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showRecordingDiagnostics(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _RecordingDiagnosticsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider);
    final settings = ref.watch(settingsProvider);
    final isLocalMode = settings.localModeEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Connection Status
          _SectionHeader('Connection'),
          _ConnectionInfoTile(isLocalMode: isLocalMode),
          const Divider(),

          // My Robots (cloud mode only). Build 110: collapsed the old inline
          // device list into a single tap-through tile. The list, select,
          // pair-new, and unpair actions all live on the unified /device-pairing
          // ("My Robots") screen now — having both was the source of the
          // "why do I see my robot twice" confusion.
          if (!isLocalMode) ...[
            _SectionHeader('My Robots'),
            const _ManageDevicesTile(),
            const Divider(),
          ],

          // WiFi Setup Help
          const _WiFiSetupHelp(),
          const Divider(),

          // Controller pairing (robot-hosted Bluetooth). Shown in both modes —
          // most useful in local-AP during field deployment, where re-pairing a
          // dropped Xbox controller otherwise means SSH.
          _SectionHeader('Controller'),
          ListTile(
            leading: const Icon(Icons.sports_esports),
            title: const Text('Game Controller'),
            subtitle: const Text('Pair a game controller to the robot'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/controller-pairing'),
          ),
          const Divider(),

          _SectionHeader('Robot Status'),
          ListTile(
            leading: Icon(
              telemetry.isCharging ? Icons.battery_charging_full : Icons.battery_full,
              color: telemetry.battery > 20 ? Colors.green : Colors.red,
            ),
            title: const Text('Battery'),
            trailing: Text(
              '${telemetry.battery.toInt()}%${telemetry.isCharging ? ' ⚡' : ''}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: const Text('Temperature'),
            trailing: Text(telemetry.temperature > 0 ? '${telemetry.temperature.toInt()}°C' : 'N/A'),
          ),
          _TreatsRemainingTile(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Current Mode'),
            trailing: Text(telemetry.mode.toUpperCase()),
          ),
          const Divider(),

          _SectionHeader('Calibration'),
          _MotorTrimSlider(),
          const Divider(),

          _SectionHeader('Camera'),
          const _CameraTrackingTile(),
          const Divider(),

          _SectionHeader('Night Vision'),
          const NightVisionSettingsSection(),
          const Divider(),

          _SectionHeader('Video'),
          const _VideoQualityTile(),
          const Divider(),

          _SectionHeader('Audio'),
          const _BackgroundAudioTile(),
          const Divider(),

          _SectionHeader('Notifications'),
          const _NotificationsTile(),
          const Divider(),

          _SectionHeader('Silent Guardian'),
          const InterventionLevelSection(),
          const Divider(),

          _SectionHeader('Training'),
          const _DailyLimitTile(),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Training Scheduler'),
            subtitle: const Text('Schedule automatic training sessions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/scheduler'),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Voice Commands'),
            subtitle: const Text('Record custom voice commands for your dog'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/voice-setup'),
          ),
          const Divider(),

          _SectionHeader('Diagnostics'),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Test Recording'),
            subtitle: const Text('Run recording diagnostics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRecordingDiagnostics(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.lan),
            title: const Text('Connection Diagnostics'),
            subtitle: const Text('WebRTC signaling trace (video connect)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/connection-diagnostics'),
          ),
          ListTile(
            leading: const Icon(Icons.preview),
            title: const Text('UI Previews'),
            subtitle: const Text('Spec-shaped views on sample data (dev)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ui-previews'),
          ),
          const Divider(),

          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('WIM-Z App'),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('API Version'),
            subtitle: Text('v1'),
          ),
          const Divider(),

          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out'),
            subtitle: Text(
              ref.watch(authProvider).email ?? '',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
/// Host selection dropdown — WIMZ Server (relay) or WIMZ Robot (local)
/// Read-only connection info — shows current mode and status.
/// To change connection mode, go back to login screen.
class _ConnectionInfoTile extends ConsumerWidget {
  final bool isLocalMode;
  const _ConnectionInfoTile({required this.isLocalMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localConn = ref.watch(localConnectionProvider);
    final connection = ref.watch(connectionProvider);

    final bool isConnected;
    final String title;
    final String subtitle;
    final IconData icon;
    final Color color;

    if (isLocalMode) {
      isConnected = localConn.isConnected;
      icon = Icons.wifi;
      color = isConnected ? AppTheme.accent : AppTheme.textTertiary;
      title = isConnected
          ? 'Connected to Robot (${localConn.robotIp ?? "192.168.4.1"})'
          : 'Local mode — not connected';
      subtitle = 'Direct connection via WIMZ WiFi';
    } else {
      isConnected = connection.isRobotOnline;
      icon = Icons.cloud;
      color = isConnected ? AppTheme.accent : AppTheme.textTertiary;
      title = isConnected
          ? 'Connected via Cloud'
          : connection.statusMessage;
      subtitle = 'Relay: api.wimzai.com';
    }

    return ListTile(
      leading: Icon(icon, color: color, size: 32),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isConnected ? AppTheme.accent : null,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
      ),
      trailing: isConnected
          ? const Icon(Icons.check_circle, color: AppTheme.accent, size: 20)
          : null,
    );
  }
}

/// Single tap-through tile that summarises the user's robots and opens the
/// unified My Robots (/device-pairing) screen. Build 110: replaced the old
/// inline list — the full list, select, pair, and unpair flows live on that
/// one screen now, so users no longer see their devices in two places.
class _ManageDevicesTile extends ConsumerWidget {
  const _ManageDevicesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairedDevices = ref.watch(pairedDevicesProvider);
    final activeDeviceId = ref.watch(deviceIdProvider);
    final isLocal = ref.watch(isLocalModeProvider);
    final count = pairedDevices.devices.length;

    // Resolve the active device's display name (falls back to its id).
    // Build 132: "active" = a robot was actually selected/saved, NOT
    // deviceId != defaultDeviceId — the placeholder equals a real robot's id
    // (wimz_robot_01), so that comparison hid it as the active robot.
    String? activeName;
    final hasActive = count > 0 && ref.watch(hasSelectedDeviceProvider);
    if (hasActive) {
      final match = pairedDevices.devices
          .where((d) => d.deviceId == activeDeviceId);
      if (match.isNotEmpty) {
        activeName = match.first.name ?? match.first.deviceId;
      }
    }

    final String subtitle;
    if (isLocal) {
      // Build 112: local AP mode is a single direct connection with no relay
      // device list. Never surface the stale saved relay id here — it can name
      // a different robot than the one we're physically connected to.
      subtitle = 'Local Robot · direct connection (192.168.4.1)';
    } else if (pairedDevices.isLoading && count == 0) {
      subtitle = 'Loading…';
    } else if (count == 0) {
      subtitle = 'No robots paired — tap to add one';
    } else {
      final plural = count == 1 ? 'robot' : 'robots';
      subtitle = activeName != null
          ? '$activeName · $count $plural paired'
          : '$count $plural paired — tap to select';
    }

    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: const Text('Manage Robots'),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/device-pairing'),
    );
  }
}

/// Treats remaining display — reads from treatsRemainingProvider (handles null/-1)
class _TreatsRemainingTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(treatsRemainingProvider);
    final display = count == null ? '\u2014' : (count <= 0 ? '0 (refill needed)' : '$count');

    return ListTile(
      leading: const Icon(Icons.cookie),
      title: const Text('Treats Remaining'),
      trailing: Text(display),
    );
  }
}

/// Daily treat limit toggle with count slider
class _DailyLimitTile extends ConsumerWidget {
  const _DailyLimitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.cookie,
            color: settings.dailyLimitEnabled ? AppTheme.warning : AppTheme.textTertiary,
          ),
          title: const Text('Daily Treat Limit'),
          subtitle: Text(
            settings.dailyLimitEnabled
                ? 'Max ${settings.dailyLimitCount} auto-treats per day'
                : 'No daily limit — unlimited auto-treats',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
          value: settings.dailyLimitEnabled,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setDailyLimitEnabled(value);
          },
        ),
        if (settings.dailyLimitEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('5', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: settings.dailyLimitCount.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${settings.dailyLimitCount}',
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setDailyLimitCount(value.round());
                    },
                  ),
                ),
                const Text('100', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Camera tracking toggle (Build 38)
class _CameraTrackingTile extends ConsumerWidget {
  const _CameraTrackingTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SwitchListTile(
      secondary: Icon(
        settings.cameraTrackingEnabled ? Icons.videocam : Icons.videocam_off,
        color: settings.cameraTrackingEnabled ? AppTheme.accent : AppTheme.textTertiary,
      ),
      title: const Text('Camera Track Dog'),
      subtitle: Text(
        settings.cameraTrackingEnabled
            ? 'Camera follows dog during coach/mission mode'
            : 'Camera stays centered',
        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
      ),
      value: settings.cameraTrackingEnabled,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setCameraTrackingEnabled(value);
      },
    );
  }
}

/// Video-quality override selector + current robot streaming tier.
/// The robot adapts bitrate on its own; this lets the user pin a tier.
class _VideoQualityTile extends ConsumerWidget {
  const _VideoQualityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.videoQualityMode));
    final webrtcState = ref.watch(webrtcStateProvider);
    final qualityState = ref.watch(videoQualityStateProvider);

    // "Currently streaming" line — covers the three edge cases:
    //  - WebRTC not connected        → "not connected"
    //  - connected, no state yet     → "—"
    //  - connected, state received   → the robot's live tier label
    final String streamingLabel;
    if (webrtcState != WebRTCState.connected) {
      streamingLabel = 'not connected';
    } else if (qualityState == null) {
      streamingLabel = '—';
    } else {
      streamingLabel = qualityState.tier.label;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hd),
              const SizedBox(width: 16),
              Text(
                'Video Quality',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<VideoQualityMode>(
              segments: const [
                ButtonSegment(
                    value: VideoQualityMode.auto, label: Text('Auto')),
                ButtonSegment(value: VideoQualityMode.low, label: Text('Low')),
                ButtonSegment(
                    value: VideoQualityMode.medium, label: Text('Med')),
                ButtonSegment(
                    value: VideoQualityMode.high, label: Text('High')),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                ref
                    .read(settingsProvider.notifier)
                    .setVideoQualityMode(selection.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Currently streaming: $streamingLabel',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Background audio toggle
class _BackgroundAudioTile extends ConsumerWidget {
  const _BackgroundAudioTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SwitchListTile(
      secondary: Icon(
        Icons.headphones,
        color: settings.backgroundAudioEnabled ? AppTheme.accent : AppTheme.textTertiary,
      ),
      title: const Text('Background Audio'),
      subtitle: Text(
        settings.backgroundAudioEnabled
            ? 'Keep listening when app is in background'
            : 'Audio stops when app is backgrounded',
        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
      ),
      value: settings.backgroundAudioEnabled,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setBackgroundAudioEnabled(value);
      },
    );
  }
}

/// Activity notifications — master toggle + drill-down to per-type preferences.
class _NotificationsTile extends ConsumerWidget {
  const _NotificationsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            settings.notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
            color: settings.notificationsEnabled ? AppTheme.accent : AppTheme.textTertiary,
          ),
          title: const Text('Activity Notifications'),
          subtitle: Text(
            settings.notificationsEnabled
                ? 'Show alerts on lock screen & Apple Watch'
                : 'Notifications disabled',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
          value: settings.notificationsEnabled,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setNotificationsEnabled(value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('Per-event preferences'),
          subtitle: const Text(
            'Choose which events push to the lock screen vs in-app only',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              GoRouter.of(context).go('/settings/notifications'),
        ),
      ],
    );
  }
}

/// Motor trim slider widget
class _MotorTrimSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final trimPercent = (settings.motorTrimRight * 100).round();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Motor Trim (Right)'),
          subtitle: Text(
            trimPercent == 0
                ? 'No adjustment'
                : trimPercent > 0
                    ? 'Slowing right motor by $trimPercent%'
                    : 'Speeding right motor by ${-trimPercent}%',
          ),
          trailing: TextButton(
            onPressed: trimPercent != 0
                ? () => ref.read(settingsProvider.notifier).resetMotorTrim()
                : null,
            child: const Text('Reset'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('-50%', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: settings.motorTrimRight,
                  min: -0.5,
                  max: 0.5,
                  divisions: 100,
                  label: '${trimPercent > 0 ? '+' : ''}$trimPercent%',
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setMotorTrimRight(value);
                  },
                ),
              ),
              const Text('+50%', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'If robot drifts LEFT, increase trim. If it drifts RIGHT, decrease trim.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// WiFi setup help expandable section
class _WiFiSetupHelp extends StatelessWidget {
  const _WiFiSetupHelp();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ExpansionTile(
      leading: const Icon(Icons.wifi_tethering),
      title: const Text('WiFi Setup Help'),
      subtitle: const Text('How to connect your robot'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connecting Your WIM-Z to WiFi',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _SetupStep(number: '1', text: 'Power on your WIM-Z robot'),
        _SetupStep(
          number: '2',
          text: 'If not connected to WiFi, it creates a hotspot called "WIMZ-XXXX"',
        ),
        _SetupStep(
          number: '3',
          text: 'On your phone, go to Settings → WiFi',
        ),
        _SetupStep(
          number: '4',
          text: 'Connect to "WIMZ-XXXX"',
          detail: 'Password: wimzsetup',
        ),
        _SetupStep(
          number: '5',
          text: 'Open your browser and go to:',
          detail: 'http://192.168.4.1',
        ),
        _SetupStep(
          number: '6',
          text: 'Select your home WiFi network and enter the password',
        ),
        _SetupStep(
          number: '7',
          text: 'Robot will reboot and connect to your network',
        ),
        _SetupStep(
          number: '8',
          text: 'Return to this app and pair with your robot',
        ),

        const SizedBox(height: 16),
        Text(
          'LED Status Guide',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _LedIndicator(
          color: Colors.cyan,
          label: 'Spinning cyan',
          meaning: 'Searching for WiFi',
        ),
        _LedIndicator(
          color: Colors.blue,
          label: 'Pulsing blue',
          meaning: 'Setup mode (connect to WIMZ hotspot)',
        ),
        _LedIndicator(
          color: Colors.green,
          label: 'Solid green',
          meaning: 'Connected to WiFi',
        ),
        _LedIndicator(
          color: Colors.red,
          label: 'Pulsing red',
          meaning: 'Error',
        ),
      ],
    );
  }
}

/// A single setup step with number badge
class _SetupStep extends StatelessWidget {
  final String number;
  final String text;
  final String? detail;

  const _SetupStep({
    required this.number,
    required this.text,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// LED status indicator row
class _LedIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final String meaning;

  const _LedIndicator({
    required this.color,
    required this.label,
    required this.meaning,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label = ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              meaning,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network status indicator — polls GET /system/network-status every 5s
class _NetworkStatusIndicator extends ConsumerStatefulWidget {
  const _NetworkStatusIndicator();

  @override
  ConsumerState<_NetworkStatusIndicator> createState() =>
      _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState
    extends ConsumerState<_NetworkStatusIndicator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wifiConfigProvider.notifier).startStatusPolling();
    });
  }

  @override
  void dispose() {
    // Don't stop polling here — provider lifecycle handles it.
    // But if we want to be polite when the tile collapses:
    // We can't call ref in dispose, so the provider's own dispose handles cleanup.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(wifiConfigProvider).networkStatus;

    if (status == null) {
      return const SizedBox.shrink();
    }

    final modeLabel = status.isAP ? 'Hotspot (AP)' : status.isWifi ? 'WiFi' : status.mode;
    final modeColor = status.isAP ? AppTheme.warning : AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: modeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isAP ? Icons.wifi_tethering : Icons.wifi,
                size: 16,
                color: modeColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Robot Network',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: modeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statusRow('Mode', modeLabel),
          if (status.networkName.isNotEmpty)
            _statusRow('Network', status.networkName),
          if (status.ipAddress.isNotEmpty)
            _statusRow('IP', status.ipAddress),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// WiFi configuration bottom sheet
class _WifiConfigSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _WifiConfigSheet({required this.scrollController});

  @override
  ConsumerState<_WifiConfigSheet> createState() => _WifiConfigSheetState();
}

class _WifiConfigSheetState extends ConsumerState<_WifiConfigSheet> {
  final _passwordController = TextEditingController();
  String? _selectedSsid;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Start scanning immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wifiConfigProvider.notifier).scanNetworks();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wifiState = ref.watch(wifiConfigProvider);
    final localConn = ref.watch(localConnectionProvider);

    // If we sent connect and local connection dropped, notify provider
    if (wifiState.step == WifiConfigStep.connectSent && !localConn.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wifiConfigProvider.notifier).onConnectionLost();
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.wifi, color: AppTheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Configure Robot WiFi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (wifiState.step == WifiConfigStep.scanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _buildSheetContent(wifiState),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent(WifiConfigState wifiState) {
    switch (wifiState.step) {
      case WifiConfigStep.idle:
      case WifiConfigStep.scanning:
        return _buildScanningView();

      case WifiConfigStep.scanComplete:
        return _buildNetworkList(wifiState);

      case WifiConfigStep.scanError:
        return _buildErrorView(wifiState.errorMessage ?? 'Scan failed');

      case WifiConfigStep.connecting:
        return _buildConnectingView();

      case WifiConfigStep.connectSent:
        return _buildWaitingView();

      case WifiConfigStep.connectionLost:
        return _buildConnectionLostView();
    }
  }

  Widget _buildScanningView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning for WiFi networks...'),
        ],
      ),
    );
  }

  Widget _buildNetworkList(WifiConfigState wifiState) {
    final networks = wifiState.networks;

    return Column(
      children: [
        Expanded(
          child: networks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 48, color: AppTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text('No WiFi networks found'),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(wifiConfigProvider.notifier).scanNetworks(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: networks.length,
                  itemBuilder: (context, index) {
                    final network = networks[index];
                    final isSelected = _selectedSsid == network.ssid;

                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            _signalIcon(network.signal),
                            color: isSelected ? AppTheme.primary : null,
                          ),
                          title: Text(
                            network.ssid,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primary : null,
                            ),
                          ),
                          subtitle: Text(
                            '${_signalLabel(network.signal)}${network.security.isNotEmpty ? ' · ${network.security}' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textTertiary),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            setState(() => _selectedSsid = network.ssid);
                          },
                        ),
                        // Password field expands under selected network
                        if (isSelected)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter WiFi password',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() =>
                                            _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(wifiConfigProvider.notifier)
                                          .connectToNetwork(
                                            _selectedSsid!,
                                            _passwordController.text,
                                          );
                                    },
                                    icon: const Icon(Icons.wifi),
                                    label: const Text('Connect'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: AppTheme.background,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (wifiState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              wifiState.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        // Rescan button at bottom
        if (networks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedSsid = null);
                  ref.read(wifiConfigProvider.notifier).scanNetworks();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan Again'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(wifiConfigProvider.notifier).scanNetworks(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Robot is connecting to WiFi...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a moment.',
            style: TextStyle(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.warning),
            SizedBox(height: 16),
            Text(
              'Robot is switching to WiFi...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'The local hotspot will shut down.\n'
              'Your connection may drop shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionLostView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 56, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'WiFi command sent!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Robot is switching to WiFi. '
              'Connect your phone to the same WiFi network, '
              'then disable Local Mode to use relay connection.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _signalIcon(int signal) {
    // signal is typically negative dBm (e.g., -30 = excellent, -90 = poor)
    // or could be 0-100 percentage — handle both
    final strength = signal < 0 ? signal : -(100 - signal);
    if (strength > -50) return Icons.wifi;
    if (strength > -70) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  String _signalLabel(int signal) {
    final strength = signal < 0 ? signal : -(100 - signal);
    if (strength > -50) return 'Excellent';
    if (strength > -70) return 'Good';
    if (strength > -80) return 'Fair';
    return 'Weak';
  }
}

/// Recording diagnostics dialog
class _RecordingDiagnosticsDialog extends ConsumerStatefulWidget {
  const _RecordingDiagnosticsDialog();

  @override
  ConsumerState<_RecordingDiagnosticsDialog> createState() =>
      _RecordingDiagnosticsDialogState();
}

class _RecordingDiagnosticsDialogState
    extends ConsumerState<_RecordingDiagnosticsDialog> {
  String _results = '';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results = 'Running diagnostics...\n';
    });

    try {
      final notifier = ref.read(pushToTalkProvider.notifier);
      final results = await notifier.runDiagnostics();
      setState(() {
        _results = results;
        _isRunning = false;
      });
    } catch (e, stack) {
      setState(() {
        _results = 'DIAGNOSTICS ERROR: $e\n\nStack: $stack';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: AppTheme.accent),
          const SizedBox(width: 8),
          const Text('Recording Diagnostics'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRunning)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Running tests...'),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _results,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRunning ? null : _runDiagnostics,
          child: const Text('Run Again'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
