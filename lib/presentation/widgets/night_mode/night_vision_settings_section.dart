import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/night_mode_state.dart';
import '../../../domain/providers/night_mode_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Settings panel for the robot's day/night camera mode. Mounts into the
/// main Settings screen under the "Camera & Night Vision" section.
class NightVisionSettingsSection extends ConsumerWidget {
  const NightVisionSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nightModeProvider);
    final isStale = ref.watch(nightModeIsStaleProvider);
    final l = context.l10n;

    if (state == null) {
      return ListTile(
        leading: const Icon(Icons.nights_stay_outlined),
        title: Text(l.nightVisionTitle),
        subtitle: Text(l.nightVisionWaiting),
      );
    }

    final isNight = state.currentMode == DayNight.night;
    // Day/night is said by the icon + word; both are ink (no cool tint).
    final w = context.wimz;
    final accent = w.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current mode + lux row
          Row(
            children: [
              Icon(
                isNight ? Icons.nights_stay : Icons.wb_sunny,
                color: isStale ? w.inkMuted : accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNight ? l.nightVisionNightMode : l.nightVisionDayMode,
                      style: TextStyle(
                        color: isStale ? w.inkMuted : accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _luxLine(l, state.currentLux),
                      style: TextStyle(
                        color: w.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isStale)
                Tooltip(
                  message: l.nightVisionStaleTooltip,
                  child: Icon(
                    Icons.cloud_off,
                    color: w.inkMuted,
                    size: 20,
                  ),
                ),
            ],
          ),

          // Last transition timestamp
          if (state.lastChangedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastChangedLine(l, state.lastChangedAt!, isNight),
              style: TextStyle(
                color: w.inkMuted,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Override selector
          SegmentedButton<NightModeOverride>(
            segments: [
              ButtonSegment(
                value: NightModeOverride.auto,
                label: Text(l.nightVisionAuto),
                icon: const Icon(Icons.brightness_auto, size: 18),
              ),
              ButtonSegment(
                value: NightModeOverride.forceDay,
                label: Text(l.nightVisionDay),
                icon: const Icon(Icons.wb_sunny, size: 18),
              ),
              ButtonSegment(
                value: NightModeOverride.forceNight,
                label: Text(l.nightVisionNight),
                icon: const Icon(Icons.nights_stay, size: 18),
              ),
            ],
            selected: {state.override},
            onSelectionChanged: (set) {
              if (set.isEmpty) return;
              ref.read(nightModeProvider.notifier).setOverride(set.first);
            },
            // Colours from segmentedButtonTheme (selected = primary).
          ),

          const SizedBox(height: 10),

          // Helper text or override-active notice
          Text(
            state.override == NightModeOverride.auto
                ? l.nightVisionAutoHint
                : l.nightVisionOverrideHint,
            style: TextStyle(
              color: state.override == NightModeOverride.auto
                  ? w.inkMuted
                  : w.ink,
              fontSize: 12,
            ),
          ),

          if (isStale) ...[
            const SizedBox(height: 8),
            Text(
              l.nightVisionOfflineHint,
              style: TextStyle(
                color: w.inkMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _luxLine(AppLocalizations l, double? lux) {
    final label = luxLocalizedLabel(l, lux);
    if (lux == null) return l.nightVisionLighting(label);
    return l.nightVisionLux(lux.toStringAsFixed(1), label);
  }

  String _lastChangedLine(AppLocalizations l, DateTime ts, bool isNight) {
    final ago = DateTime.now().difference(ts);
    final modeWord =
        isNight ? l.nightVisionModeWordNight : l.nightVisionModeWordDay;
    if (ago.inSeconds < 60) {
      return l.nightVisionSwitchedSecondsAgo(modeWord, ago.inSeconds);
    }
    if (ago.inMinutes < 60) {
      return l.nightVisionSwitchedMinutesAgo(modeWord, ago.inMinutes);
    }
    if (ago.inHours < 24) {
      return l.nightVisionSwitchedHoursAgo(modeWord, ago.inHours);
    }
    return l.nightVisionSwitchedDaysAgo(modeWord, ago.inDays);
  }
}
