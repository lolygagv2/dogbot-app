import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/providers/demo_replay_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Admin-only strip at the bottom of the demo view: replayer buttons plus
/// `replay_active` (status endpoint) and the virtual clock. Renders nothing
/// unless the relay has confirmed this account is an admin.
class DemoControlsPanel extends ConsumerStatefulWidget {
  const DemoControlsPanel({super.key});

  @override
  ConsumerState<DemoControlsPanel> createState() => _DemoControlsPanelState();
}

class _DemoControlsPanelState extends ConsumerState<DemoControlsPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(demoReplayProvider.notifier).attach();
    });
    // Advance the displayed virtual clock between polls.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(demoReplayProvider).replay.isRunning) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    ref.read(demoReplayProvider.notifier).detach();
    super.dispose();
  }

  /// Snapshot clock + elapsed wall time × speed while the replayer runs.
  DateTime? _clock(DemoReplayState s) {
    final base = s.virtualWallTime;
    if (base == null) return null;
    if (!s.replay.isRunning) return base;
    final elapsed = DateTime.now().difference(s.snapshotAt);
    return base.add(Duration(
        milliseconds: (elapsed.inMilliseconds * s.replay.speed).round()));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(demoReplayProvider);
    if (s.isAdmin != true) return const SizedBox.shrink();
    final l = context.l10n;
    final n = ref.read(demoReplayProvider.notifier);
    final loaded = s.replay.isLoaded;
    final clock = _clock(s);
    final locale = Localizations.localeOf(context).toString();
    final clockText =
        clock == null ? '––:––:––' : DateFormat.Hms(locale).format(clock);
    final active = s.replayActive;
    final activeColor = active == null
        ? AppTheme.textTertiary
        : (active ? AppTheme.accent : AppTheme.textTertiary);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined,
                  size: 14, color: AppTheme.warning),
              const SizedBox(width: 6),
              Text(
                l.demoControlsTitle.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppTheme.warning,
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
                color: loaded ? AppTheme.primary : AppTheme.textTertiary,
                mono: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _detail(l, s),
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (s.busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.warning),
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
                color: AppTheme.accent,
                enabled: !s.busy,
                onTap: n.loadGoodDay,
              ),
              _Btn(
                label: l.demoLoadBadDay,
                icon: Icons.thunderstorm_outlined,
                color: AppTheme.error,
                enabled: !s.busy,
                onTap: n.loadBadDay,
              ),
              _Btn(
                label: l.demoStartSpeed(120),
                icon: Icons.play_arrow,
                color: AppTheme.primary,
                enabled: !s.busy && loaded && !s.replay.isRunning,
                onTap: () => n.start(speed: 120),
              ),
              if (s.replay.isRunning)
                _Btn(
                  label: l.demoPause,
                  icon: Icons.pause,
                  color: AppTheme.primary,
                  enabled: !s.busy,
                  onTap: n.pause,
                ),
              _Btn(
                label: l.demoJumpTo('15:30'),
                icon: Icons.fast_forward,
                color: AppTheme.secondary,
                enabled: !s.busy && loaded,
                onTap: () => n.jumpTo('15:30'),
              ),
              _Btn(
                label: l.demoJumpTo('17:00'),
                icon: Icons.fast_forward,
                color: AppTheme.secondary,
                enabled: !s.busy && loaded,
                onTap: () => n.jumpTo('17:00'),
              ),
              _Btn(
                label: l.demoReset,
                icon: Icons.restart_alt,
                color: AppTheme.warning,
                enabled: !s.busy,
                onTap: n.reset,
              ),
            ],
          ),
          if (s.error != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 12, color: AppTheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s.error!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: n.clearError,
                  child: const Icon(Icons.close,
                      size: 14, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "running · Bezik good day · 12/24 · 120×" style summary.
  String _detail(AppLocalizations l, DemoReplayState s) {
    final r = s.replay;
    if (r.isIdle) return l.demoReplayIdle;
    final speed = r.speed == r.speed.roundToDouble()
        ? '${r.speed.round()}×'
        : '${r.speed.toStringAsFixed(1)}×';
    return [
      _statusLabel(l, r.status),
      if (r.name != null) r.name!,
      '${r.cursor}/${r.total}',
      speed,
      if (r.dogId != null) r.dogId!,
    ].join(' · ');
  }

  String _statusLabel(AppLocalizations l, String status) => switch (status) {
        'loaded' => l.demoReplayStatusLoaded,
        'running' => l.demoReplayStatusRunning,
        'paused' => l.demoReplayStatusPaused,
        'done' => l.demoReplayStatusDone,
        _ => status,
      };
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
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
          disabledForegroundColor: color.withOpacity(0.3),
          side: BorderSide(color: color.withOpacity(enabled ? 0.6 : 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
        ),
      );
}
