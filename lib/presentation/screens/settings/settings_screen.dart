import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_connection_service.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/locale_provider.dart';
import '../../../domain/providers/ota_update_provider.dart';
import '../../../domain/providers/paired_devices_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../domain/providers/sounds_provider.dart';
import '../../../domain/providers/push_to_talk_provider.dart';
import '../../../data/models/telemetry.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../../domain/providers/video_quality_provider.dart';
import '../../../domain/providers/webrtc_provider.dart';
import '../../../domain/providers/wifi_config_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_mode/night_vision_settings_section.dart';
import '../../widgets/status/local_ap_banner.dart';
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
        title: Text(ctx.l10n.signOut),
        content: Text(ctx.l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.signOut, style: const TextStyle(color: Colors.red)),
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
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          // Connection Status
          _SectionHeader(l.settingsSectionConnection),
          _ConnectionInfoTile(isLocalMode: isLocalMode),
          // Build 146: in-session switch onto the robot's hotspot (cloud only)
          if (!isLocalMode) const LocalModeSwitchTile(),
          const Divider(),

          // My Robots (cloud mode only). Build 110: collapsed the old inline
          // device list into a single tap-through tile. The list, select,
          // pair-new, and unpair actions all live on the unified /device-pairing
          // ("My Robots") screen now — having both was the source of the
          // "why do I see my robot twice" confusion.
          if (!isLocalMode) ...[
            _SectionHeader(l.settingsSectionMyRobots),
            const _ManageDevicesTile(),
            const Divider(),
          ],

          // WiFi Setup Help
          const _WiFiSetupHelp(),
          const Divider(),

          // Controller pairing (robot-hosted Bluetooth). Shown in both modes —
          // most useful in local-AP during field deployment, where re-pairing a
          // dropped Xbox controller otherwise means SSH.
          _SectionHeader(l.settingsSectionController),
          ListTile(
            leading: const Icon(Icons.sports_esports),
            title: Text(l.settingsGameController),
            subtitle: Text(l.settingsGameControllerSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/controller-pairing'),
          ),
          const Divider(),

          _SectionHeader(l.settingsSectionRobotStatus),
          ListTile(
            leading: Icon(
              telemetry.isCharging ? Icons.battery_charging_full : Icons.battery_full,
              color: telemetry.battery > 20 ? Colors.green : Colors.red,
            ),
            title: Text(l.settingsBattery),
            trailing: Text(
              '${telemetry.battery.toInt()}%${telemetry.isCharging ? ' ⚡' : ''}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: Text(l.settingsTemperature),
            trailing: Text(telemetry.temperature > 0 ? '${telemetry.temperature.toInt()}°C' : l.settingsNotAvailable),
          ),
          _TreatsRemainingTile(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l.settingsCurrentMode),
            trailing: Text(robotModeIdLabel(l, telemetry.mode).toUpperCase()),
          ),
          const _RobotSoftwareTile(),
          const Divider(),

          _SectionHeader(l.settingsSectionCalibration),
          _MotorTrimSlider(),
          const Divider(),

          _SectionHeader(l.settingsSectionCamera),
          const _CameraTrackingTile(),
          const Divider(),

          _SectionHeader(l.settingsSectionNightVision),
          const NightVisionSettingsSection(),
          const Divider(),

          _SectionHeader(l.settingsSectionVideo),
          const _VideoQualityTile(),
          const Divider(),

          _SectionHeader(l.settingsSectionAudio),
          const _BackgroundAudioTile(),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: Text(l.songUploadTitle),
            subtitle: Text(l.settingsSongUploadSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/song-upload'),
          ),
          const _ResetSoundsTile(),
          if (settings.advancedModeEnabled)
            ListTile(
              leading: const Icon(Icons.graphic_eq, color: AppTheme.secondary),
              title: Text(l.settingsSoundsAll),
              subtitle: Text(l.settingsSoundsAllSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/sounds'),
            ),
          const Divider(),

          // Connected AI (ChatGPT / Claude / Grok / Perplexity via the relay
          // connector) — cloud only; local-AP has no relay.
          if (!isLocalMode) ...[
            _SectionHeader(l.connectedAiTitle),
            ListTile(
              leading: const Icon(Icons.hub_outlined, color: AppTheme.secondary),
              title: Text(l.connectedAiTitle),
              subtitle: Text(l.connectedAiSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/connected-ai'),
            ),
            const Divider(),
          ],

          _SectionHeader(l.settingsSectionNotifications),
          const _NotificationsTile(),
          const Divider(),

          _SectionHeader(l.settingsSectionSilentGuardian),
          const InterventionLevelSection(),
          const Divider(),

          _SectionHeader(l.settingsSectionTraining),
          const _DailyLimitTile(),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l.settingsTrainingScheduler),
            subtitle: Text(l.settingsTrainingSchedulerSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/scheduler'),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: Text(l.settingsVoiceCommands),
            subtitle: Text(l.settingsVoiceCommandsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/voice-setup'),
          ),
          const Divider(),

          _SectionHeader(l.settingsSectionDemo),
          ListTile(
            leading: const Icon(Icons.cast, color: AppTheme.primary),
            title: Text(l.demoViewTitle),
            subtitle: Text(l.demoViewSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/demo-view'),
          ),
          const Divider(),

          _SectionHeader(l.settingsSectionAdvanced),
          SwitchListTile(
            secondary: Icon(
              Icons.science_outlined,
              color: settings.advancedModeEnabled
                  ? AppTheme.secondary
                  : AppTheme.textTertiary,
            ),
            title: Text(l.settingsAdvancedMode),
            subtitle: Text(
              l.settingsAdvancedModeSubtitle,
              style: const TextStyle(fontSize: 12),
            ),
            value: settings.advancedModeEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAdvancedModeEnabled(v),
          ),
          const Divider(),

          _SectionHeader(l.settingsSectionDiagnostics),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(l.settingsTestRecording),
            subtitle: Text(l.settingsTestRecordingSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRecordingDiagnostics(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.lan),
            title: Text(l.settingsConnectionDiagnostics),
            subtitle: Text(l.settingsConnectionDiagnosticsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/connection-diagnostics'),
          ),
          ListTile(
            leading: const Icon(Icons.preview),
            title: Text(l.settingsUiPreviews),
            subtitle: Text(l.settingsUiPreviewsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ui-previews'),
          ),
          const Divider(),

          _SectionHeader(l.language),
          const _LanguageTile(),
          const Divider(),

          _SectionHeader(l.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l.settingsAppName),
            subtitle: Text(l.settingsAppVersion('1.0.0')),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l.settingsApiVersion),
            subtitle: const Text('v1'),
          ),
          const Divider(),

          _SectionHeader(l.settingsSectionAccount),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l.signOut),
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

/// Settings → Language. Null locale = follow the device language.
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  static String _label(AppLocalizations l, Locale? locale) {
    switch (locale?.languageCode) {
      case 'en':
        return l.languageEnglish;
      case 'ko':
        return l.languageKorean;
      default:
        return l.languageSystemDefault;
    }
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final current = ref.read(localeProvider);
    // Sentinel so "system default" (null) is distinguishable from "dismissed".
    const system = Locale('und');
    final chosen = await showDialog<Locale>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.language),
        children: [
          for (final entry in <Locale, String>{
            system: l.languageSystemDefault,
            const Locale('en'): l.languageEnglish,
            const Locale('ko'): l.languageKorean,
          }.entries)
            RadioListTile<Locale>(
              value: entry.key,
              groupValue: current ?? system,
              title: Text(entry.value),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref
        .read(localeProvider.notifier)
        .setLocale(chosen == system ? null : chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider);
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l.language),
      subtitle: Text(
        '${_label(l, locale)} · ${l.languageSubtitle}',
        style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
      ),
      onTap: () => _pick(context, ref),
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
    final l = context.l10n;

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
          ? l.settingsConnectedToRobot(localConn.robotIp ?? '192.168.4.1')
          : l.settingsLocalNotConnected;
      subtitle = l.settingsDirectViaWifi;
    } else {
      isConnected = connection.isRobotOnline;
      icon = Icons.cloud;
      color = isConnected ? AppTheme.accent : AppTheme.textTertiary;
      title = isConnected
          ? l.settingsConnectedViaCloud
          : connection.statusMessage(l);
      subtitle = l.settingsRelayHost('api.wimzai.com');
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
    final l = context.l10n;

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
      subtitle = l.settingsLocalRobotDirect;
    } else if (pairedDevices.isLoading && count == 0) {
      subtitle = l.loading;
    } else if (count == 0) {
      subtitle = l.settingsNoRobotsPaired;
    } else {
      subtitle = activeName != null
          ? l.settingsRobotsPairedActive(activeName, count)
          : l.settingsRobotsPairedSelect(count);
    }

    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: Text(l.settingsManageRobots),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/device-pairing'),
    );
  }
}

/// OTA contract 2026-08-07, app slice: robot's running software version vs
/// the relay's latest release, UPDATE button when newer, live progress from
/// update_status events. Degrades gracefully while the other slices are
/// unshipped: no sw_version in telemetry → "not reported"; relay 404 → no
/// update offered.
class _RobotSoftwareTile extends ConsumerWidget {
  const _RobotSoftwareTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(telemetryProvider).swVersion;
    final latestAsync = ref.watch(latestReleaseProvider);
    final ota = ref.watch(otaUpdateProvider);
    final l = context.l10n;

    final latest = latestAsync.valueOrNull;
    final latestVersion = latest?['version'] as String?;
    // v1 comparison per contract: any different, non-null relay version
    // counts as "update available" (versions are date-tags, not semver).
    final updateAvailable = latestVersion != null &&
        running != null &&
        latestVersion != running &&
        !ota.inProgress;

    final String subtitle;
    Color? subtitleColor;
    if (ota.inProgress) {
      final pct = ota.progressPct != null ? ' ${ota.progressPct}%' : '';
      subtitle = l.settingsOtaUpdating(ota.version ?? '?', ota.state ?? '', pct);
      subtitleColor = AppTheme.accent;
    } else if (ota.isTerminal) {
      switch (ota.state) {
        case 'success':
          subtitle = l.settingsOtaUpdated(ota.version ?? '?');
          subtitleColor = Colors.green;
          break;
        case 'rolled_back':
          subtitle = l.settingsOtaRolledBack(
              ota.error != null ? ' (${ota.error})' : '');
          subtitleColor = AppTheme.warning;
          break;
        default: // failed
          subtitle = l.settingsOtaFailed(
              ota.error != null ? ': ${ota.error}' : '');
          subtitleColor = AppTheme.error;
      }
    } else if (running == null) {
      subtitle = l.settingsOtaNotReported;
    } else if (latestVersion == null) {
      subtitle = l.settingsOtaUpToDateNoRelease;
    } else if (updateAvailable) {
      subtitle = l.settingsOtaAvailable(latestVersion);
      subtitleColor = AppTheme.accent;
    } else {
      subtitle = l.settingsOtaUpToDate;
    }

    return ListTile(
      leading: Icon(
        Icons.system_update_alt,
        color: updateAvailable ? AppTheme.accent : null,
      ),
      title: Text(l.settingsRobotSoftware),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor ?? AppTheme.textTertiary, fontSize: 12),
      ),
      trailing: ota.inProgress
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : ota.isTerminal
              ? TextButton(
                  onPressed: () => ref.read(otaUpdateProvider.notifier).dismiss(),
                  child: Text(l.ok),
                )
              : updateAvailable
                  ? ElevatedButton(
                      onPressed: () => _confirmUpdate(context, ref, latestVersion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                      ),
                      child: Text(l.settingsUpdateCaps),
                    )
                  : Text(running ?? '—'),
      onTap: () => ref.invalidate(latestReleaseProvider), // tap to re-check
    );
  }

  void _confirmUpdate(BuildContext context, WidgetRef ref, String version) {
    final l = context.l10n;
    final running = ref.read(telemetryProvider).swVersion ?? l.unknown;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsUpdateRobotSoftware),
        content: Text(l.settingsUpdateConfirmBody(running, version)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(otaUpdateProvider.notifier).startUpdate(version);
            },
            child: Text(l.settingsUpdate),
          ),
        ],
      ),
    );
  }
}

/// Treat counter display — treats remaining out of the fixed 44-slot
/// carousel (B160: remaining is the single rendered figure).
class _TreatsRemainingTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(treatsRemainingProvider);
    final l = context.l10n;

    final String display;
    if (remaining != null) {
      display = l.settingsTreatsOfCapacity(remaining, kTreatCapacity);
    } else {
      display = '\u2014';
    }
    final isEmpty = remaining == 0;
    final isLow = remaining != null && remaining < 5;

    return ListTile(
      leading: Icon(Icons.cookie,
          color: isEmpty
              ? AppTheme.error
              : isLow
                  ? AppTheme.warning
                  : null),
      title: Text(l.settingsTreats),
      subtitle: remaining == null
          ? null
          : Text(
              isEmpty
                  ? l.settingsTreatsEmpty
                  : isLow
                      ? l.settingsTreatsRemainingLow(remaining)
                      : l.settingsTreatsRemaining(remaining),
              style: TextStyle(
                color: isEmpty
                    ? AppTheme.error
                    : isLow
                        ? AppTheme.warning
                        : AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
      trailing: Text(
        display,
        style: isEmpty ? const TextStyle(color: AppTheme.error) : null,
      ),
    );
  }
}

/// Daily treat limit toggle with count slider
class _DailyLimitTile extends ConsumerWidget {
  const _DailyLimitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l = context.l10n;

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.cookie,
            color: settings.dailyLimitEnabled ? AppTheme.warning : AppTheme.textTertiary,
          ),
          title: Text(l.settingsDailyTreatLimit),
          subtitle: Text(
            settings.dailyLimitEnabled
                ? l.settingsDailyLimitMax(settings.dailyLimitCount)
                : l.settingsDailyLimitNone,
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
    final l = context.l10n;

    return SwitchListTile(
      secondary: Icon(
        settings.cameraTrackingEnabled ? Icons.videocam : Icons.videocam_off,
        color: settings.cameraTrackingEnabled ? AppTheme.accent : AppTheme.textTertiary,
      ),
      title: Text(l.settingsCameraTrackDog),
      subtitle: Text(
        settings.cameraTrackingEnabled
            ? l.settingsCameraTrackOn
            : l.settingsCameraTrackOff,
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
    final l = context.l10n;

    // "Currently streaming" line — covers the three edge cases:
    //  - WebRTC not connected        → "not connected"
    //  - connected, no state yet     → "—"
    //  - connected, state received   → the robot's live tier label
    final String streamingLabel;
    if (webrtcState != WebRTCState.connected) {
      streamingLabel = l.settingsStreamingNotConnected;
    } else if (qualityState == null) {
      streamingLabel = '—';
    } else {
      streamingLabel = qualityState.tier.localizedLabel(l);
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
                l.settingsVideoQuality,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<VideoQualityMode>(
              segments: [
                ButtonSegment(
                    value: VideoQualityMode.auto,
                    label: Text(l.settingsQualityAuto)),
                ButtonSegment(
                    value: VideoQualityMode.low,
                    label: Text(l.settingsQualityLow)),
                ButtonSegment(
                    value: VideoQualityMode.medium,
                    label: Text(l.settingsQualityMed)),
                ButtonSegment(
                    value: VideoQualityMode.high,
                    label: Text(l.settingsQualityHigh)),
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
            l.settingsCurrentlyStreaming(streamingLabel),
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
    final l = context.l10n;

    return SwitchListTile(
      secondary: Icon(
        Icons.headphones,
        color: settings.backgroundAudioEnabled ? AppTheme.accent : AppTheme.textTertiary,
      ),
      title: Text(l.settingsBackgroundAudio),
      subtitle: Text(
        settings.backgroundAudioEnabled
            ? l.settingsBackgroundAudioOn
            : l.settingsBackgroundAudioOff,
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
    final l = context.l10n;

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            settings.notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
            color: settings.notificationsEnabled ? AppTheme.accent : AppTheme.textTertiary,
          ),
          title: Text(l.settingsActivityNotifications),
          subtitle: Text(
            settings.notificationsEnabled
                ? l.settingsNotificationsOn
                : l.settingsNotificationsOff,
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
          value: settings.notificationsEnabled,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setNotificationsEnabled(value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(l.settingsPerEventPrefs),
          subtitle: Text(
            l.settingsPerEventPrefsSubtitle,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              GoRouter.of(context).go('/settings/notifications'),
        ),
      ],
    );
  }
}

/// Regular-settings sound control: one button, factory reset with confirm.
class _ResetSoundsTile extends ConsumerWidget {
  const _ResetSoundsTile();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settingsResetSoundsConfirmTitle),
        content: Text(ctx.l10n.settingsResetSoundsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.settingsResetSounds,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await ref.read(soundsProvider.notifier).resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null
            ? l.settingsResetSoundsDone
            : l.settingsResetSoundsFailed(err)),
        backgroundColor: err == null ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resetting = ref.watch(soundsProvider.select((s) => s.resettingAll));
    final l = context.l10n;
    return ListTile(
      leading: resetting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.settings_backup_restore),
      title: Text(l.settingsResetSounds),
      subtitle: Text(
        l.settingsResetSoundsSubtitle,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: resetting ? null : () => _confirm(context, ref),
    );
  }
}

/// Motor trim slider widget
class _MotorTrimSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final trimPercent = (settings.motorTrimRight * 100).round();
    final l = context.l10n;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(l.settingsMotorTrim),
          subtitle: Text(
            trimPercent == 0
                ? l.settingsMotorTrimNone
                : trimPercent > 0
                    ? l.settingsMotorTrimSlowing(trimPercent)
                    : l.settingsMotorTrimSpeeding(-trimPercent),
          ),
          trailing: TextButton(
            onPressed: trimPercent != 0
                ? () => ref.read(settingsProvider.notifier).resetMotorTrim()
                : null,
            child: Text(l.settingsReset),
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
            l.settingsMotorTrimHint,
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
    final l = context.l10n;

    return ExpansionTile(
      leading: const Icon(Icons.wifi_tethering),
      title: Text(l.settingsWifiHelp),
      subtitle: Text(l.settingsWifiHelpSubtitle),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.settingsWifiHelpTitle,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _SetupStep(number: '1', text: l.settingsWifiStep1),
        _SetupStep(number: '2', text: l.settingsWifiStep2),
        _SetupStep(number: '3', text: l.settingsWifiStep3),
        _SetupStep(
          number: '4',
          text: l.settingsWifiStep4,
          detail: l.settingsWifiStep4Detail,
        ),
        _SetupStep(
          number: '5',
          text: l.settingsWifiStep5,
          detail: 'http://192.168.4.1',
        ),
        _SetupStep(number: '6', text: l.settingsWifiStep6),
        _SetupStep(number: '7', text: l.settingsWifiStep7),
        _SetupStep(number: '8', text: l.settingsWifiStep8),

        const SizedBox(height: 16),
        Text(
          l.settingsLedGuide,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _LedIndicator(
          color: Colors.cyan,
          label: l.settingsLedSpinningCyan,
          meaning: l.settingsLedSearchingWifi,
        ),
        _LedIndicator(
          color: Colors.blue,
          label: l.settingsLedPulsingBlue,
          meaning: l.settingsLedSetupMode,
        ),
        _LedIndicator(
          color: Colors.green,
          label: l.settingsLedSolidGreen,
          meaning: l.settingsLedConnectedWifi,
        ),
        _LedIndicator(
          color: Colors.red,
          label: l.settingsLedPulsingRed,
          meaning: l.error,
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

    final l = context.l10n;
    final modeLabel = status.isAP
        ? l.settingsNetHotspot
        : status.isWifi
            ? l.settingsNetWifi
            : robotModeIdLabel(l, status.mode);
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
                l.settingsRobotNetwork,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: modeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statusRow(l.settingsNetMode, modeLabel),
          if (status.networkName.isNotEmpty)
            _statusRow(l.settingsNetNetwork, status.networkName),
          if (status.ipAddress.isNotEmpty)
            _statusRow(l.settingsNetIp, status.ipAddress),
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
                Text(
                  context.l10n.settingsConfigureRobotWifi,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        return _buildErrorView(
            wifiState.errorMessage ?? context.l10n.settingsWifiScanFailed);

      case WifiConfigStep.connecting:
        return _buildConnectingView();

      case WifiConfigStep.connectSent:
        return _buildWaitingView();

      case WifiConfigStep.connectionLost:
        return _buildConnectionLostView();
    }
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.settingsWifiScanning),
        ],
      ),
    );
  }

  Widget _buildNetworkList(WifiConfigState wifiState) {
    final networks = wifiState.networks;
    final l = context.l10n;

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
                      Text(l.settingsWifiNoneFound),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(wifiConfigProvider.notifier).scanNetworks(),
                        icon: const Icon(Icons.refresh),
                        label: Text(l.settingsWifiScanAgain),
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
                                    labelText: l.settingsWifiPassword,
                                    hintText: l.settingsWifiPasswordHint,
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
                                    label: Text(l.settingsWifiConnect),
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
                label: Text(l.settingsWifiScanAgain),
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
              label: Text(context.l10n.settingsTryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingView() {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l.settingsWifiRobotConnecting,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            l.settingsWifiMayTakeMoment,
            style: const TextStyle(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.warning),
            const SizedBox(height: 16),
            Text(
              l.settingsWifiRobotSwitching,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              l.settingsWifiHotspotShutdown,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionLostView() {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 56, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(
              l.settingsWifiCommandSent,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              l.settingsWifiCommandSentBody,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
              ),
              child: Text(l.settingsGotIt),
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
    final l = context.l10n;
    final strength = signal < 0 ? signal : -(100 - signal);
    if (strength > -50) return l.settingsSignalExcellent;
    if (strength > -70) return l.settingsSignalGood;
    if (strength > -80) return l.settingsSignalFair;
    return l.settingsSignalWeak;
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
    final l = context.l10n;
    setState(() {
      _isRunning = true;
      _results = '${l.settingsDiagRunning}\n';
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
        _results = l.settingsDiagError('$e', '$stack');
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(l.settingsRecordingDiagnostics),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRunning)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(l.settingsRunningTests),
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
          child: Text(l.settingsRunAgain),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}
