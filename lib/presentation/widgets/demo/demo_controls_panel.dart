import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/push_service.dart';

import '../../../domain/providers/demo_replay_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Admin-only strip at the bottom of the demo view: replayer buttons plus
/// `replay.active` and the virtual clock for the SELECTED dog. Everything
/// shown is the relay's last answer — nothing is advanced locally — and a
/// failed call shows its HTTP status and error text. Renders nothing unless
/// the relay has confirmed this account is an admin.
class DemoControlsPanel extends ConsumerStatefulWidget {
  const DemoControlsPanel({super.key});

  @override
  ConsumerState<DemoControlsPanel> createState() => _DemoControlsPanelState();
}

class _DemoControlsPanelState extends ConsumerState<DemoControlsPanel>
    with WidgetsBindingObserver {
  /// Phone-level notification permission for the app (null = unknown).
  bool? _phoneNotifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(demoReplayProvider.notifier).attach();
    });
    _checkNotifications();
  }

  /// Re-read on return from the phone's Settings app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    final allowed = await PushService.instance.notificationsAllowed();
    if (mounted && allowed != _phoneNotifications) {
      setState(() => _phoneNotifications = allowed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(demoReplayProvider.notifier).detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(demoReplayProvider);
    if (s.isAdmin != true) return const SizedBox.shrink();
    final l = context.l10n;
    final n = ref.read(demoReplayProvider.notifier);
    final dog = ref.watch(selectedDogProvider);
    final robot = ref.watch(onlineRobotDeviceIdProvider);
    // Start / pause / jump act on a replay loaded for the selected dog.
    final loaded = s.replayIsFor(dog?.id);
    final clock = s.virtualWallTimeFor(dog?.id);
    final locale = Localizations.localeOf(context).toString();
    final clockText =
        clock == null ? '––:––:––' : DateFormat.Hms(locale).format(clock);
    final active = s.replayActive;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;
    // "Replay active" is a live indicator → signal; otherwise muted.
    final activeColor = active == null
        ? w.inkMuted
        : (active ? w.signal : w.inkMuted);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: w.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: w.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined,
                  size: 14, color: w.inkMuted),
              const SizedBox(width: 6),
              Text(
                l.demoControlsTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: w.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              _Chip(
                icon: active == true
                    ? Icons.play_circle_fill
                    : Icons.radio_button_unchecked,
                label: l.demoReplayActive(
                    active == null ? '–' : (active ? l.yes : l.no)),
                color: activeColor,
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.schedule,
                label: l.demoVirtualClock(clockText),
                color: loaded ? cs.primary : w.inkMuted,
                mono: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _detail(l, s, loaded),
                  style: TextStyle(
                      fontSize: 10, color: w.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (s.busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Btn(
                label: l.demoLoadGoodDay,
                icon: Icons.wb_sunny_outlined,
                color: w.ink,
                enabled: !s.busy,
                onTap: n.loadGoodDay,
              ),
              _Btn(
                label: l.demoLoadBadDay,
                icon: Icons.thunderstorm_outlined,
                color: w.ink,
                enabled: !s.busy,
                onTap: n.loadBadDay,
              ),
              _Btn(
                label: l.demoStartSpeed(120),
                icon: Icons.play_arrow,
                color: cs.primary,
                enabled: !s.busy && loaded && !s.replay.isRunning,
                onTap: () => n.start(speed: 120),
              ),
              if (s.replay.isRunning)
                _Btn(
                  label: l.demoPause,
                  icon: Icons.pause,
                  color: cs.primary,
                  enabled: !s.busy,
                  onTap: n.pause,
                ),
              _Btn(
                label: l.demoJumpTo('15:30'),
                icon: Icons.fast_forward,
                color: w.ink,
                enabled: !s.busy && loaded,
                onTap: () => n.jumpTo('15:30'),
              ),
              _Btn(
                label: l.demoJumpTo('17:00'),
                icon: Icons.fast_forward,
                color: w.ink,
                enabled: !s.busy && loaded,
                onTap: () => n.jumpTo('17:00'),
              ),
              _Btn(
                label: l.demoReset,
                icon: Icons.restart_alt,
                color: w.inkMuted,
                enabled: !s.busy,
                onTap: n.reset,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dog == null
                ? l.demoNoDog
                : l.demoTarget(dog.name, robot ?? l.demoNoRobotOnline),
            style: TextStyle(fontSize: 11, color: w.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (s.result != null) ...[
            const SizedBox(height: 4),
            Text(
              _resultLine(l, s.result!),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: w.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_phoneNotifications == false)
            _ErrorLine(text: l.demoPhoneNotificationsOff)
          else if (!ref.watch(
              settingsProvider.select((x) => x.notificationsEnabled)))
            _ErrorLine(text: l.demoAppPushOff),
          if (s.error != null)
            _ErrorLine(text: s.error!, onClose: n.clearError),
          if (s.pollError != null) _ErrorLine(text: s.pollError!),
        ],
      ),
    );
  }

  /// "running · Bezik good day · 12/24 · 120×" for the selected dog's
  /// replay; "Replayer is on <dog>" when the relay is driving another dog.
  String _detail(AppLocalizations l, DemoReplayState s, bool forSelected) {
    final r = s.replay;
    final other = s.otherReplayDog(ref.watch(selectedDogProvider)?.id);
    if (other != null) {
      return l.demoReplayOtherDog(
          ref.watch(dogProfileProvider(other))?.name ?? other);
    }
    if (r.isIdle || !forSelected) return l.demoReplayIdle;
    final speed = r.speed == r.speed.roundToDouble()
        ? '${r.speed.round()}×'
        : '${r.speed.toStringAsFixed(1)}×';
    return [
      _statusLabel(l, r.status),
      if (r.name != null) r.name!,
      '${r.cursor}/${r.total}',
      speed,
      if (r.date != null) r.date!,
    ].join(' · ');
  }

  /// Seed · dog · replay date · what this call wrote, all from the relay's
  /// response. Good day adds the recap written onto yesterday.
  String _resultLine(AppLocalizations l, ReplayResult r) {
    final dog = ref.watch(dogProfileProvider(r.dogId))?.name ?? r.dogId;
    final removed = (r.removed ?? 0) > 0 || r.seed == null
        ? l.demoResultRemoved(r.removed?.toString() ?? '–')
        : null;
    if (r.seed == null) return '$dog · $removed';
    final landed = r.landed?.toString() ?? '–';
    final line = r.landedDate != null
        ? l.demoResultRecap(r.seed!, dog, r.date ?? '–', landed, r.landedDate!)
        : l.demoResultLine(r.seed!, dog, r.date ?? '–', landed);
    return removed == null ? line : '$line · $removed';
  }

  String _statusLabel(AppLocalizations l, String status) => switch (status) {
        'loaded' => l.demoReplayStatusLoaded,
        'running' => l.demoReplayStatusRunning,
        'paused' => l.demoReplayStatusPaused,
        'done' => l.demoReplayStatusDone,
        _ => status,
      };
}

class _ErrorLine extends StatelessWidget {
  final String text;
  final VoidCallback? onClose;
  const _ErrorLine({required this.text, this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 12, color: cs.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: cs.error),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close, size: 14, color: context.wimz.inkMuted),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool mono;
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures:
                    mono ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ],
        ),
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final Future<bool> Function() onTap;
  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: enabled ? () => onTap() : null,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color.withValues(alpha: 0.3),
          side: BorderSide(color: color.withValues(alpha: enabled ? 0.6 : 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
        ),
      );
}
