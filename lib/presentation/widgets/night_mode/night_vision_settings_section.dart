import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/night_mode_state.dart';
import '../../../domain/providers/night_mode_provider.dart';
import '../../theme/app_theme.dart';

/// Settings panel for the robot's day/night camera mode. Mounts into the
/// main Settings screen under the "Camera & Night Vision" section.
class NightVisionSettingsSection extends ConsumerWidget {
  const NightVisionSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nightModeProvider);
    final isStale = ref.watch(nightModeIsStaleProvider);

    if (state == null) {
      return const ListTile(
        leading: Icon(Icons.nights_stay_outlined),
        title: Text('Night Vision'),
        subtitle: Text('Waiting for robot…'),
      );
    }

    final isNight = state.currentMode == DayNight.night;
    final accent = isNight ? AppTheme.behaviorLying : AppTheme.primary;

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
                color: isStale ? AppTheme.textTertiary : accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNight ? 'Night vision' : 'Day mode',
                      style: TextStyle(
                        color: isStale ? AppTheme.textTertiary : accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _luxLine(state.currentLux),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isStale)
                Tooltip(
                  message: 'No update from robot in 90+ seconds',
                  child: Icon(
                    Icons.cloud_off,
                    color: AppTheme.warning.withOpacity(0.8),
                    size: 20,
                  ),
                ),
            ],
          ),

          // Last transition timestamp
          if (state.lastChangedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastChangedLine(state.lastChangedAt!, isNight),
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Override selector
          SegmentedButton<NightModeOverride>(
            segments: const [
              ButtonSegment(
                value: NightModeOverride.auto,
                label: Text('Auto'),
                icon: Icon(Icons.brightness_auto, size: 18),
              ),
              ButtonSegment(
                value: NightModeOverride.forceDay,
                label: Text('Day'),
                icon: Icon(Icons.wb_sunny, size: 18),
              ),
              ButtonSegment(
                value: NightModeOverride.forceNight,
                label: Text('Night'),
                icon: Icon(Icons.nights_stay, size: 18),
              ),
            ],
            selected: {state.override},
            onSelectionChanged: (set) {
              if (set.isEmpty) return;
              ref.read(nightModeProvider.notifier).setOverride(set.first);
            },
            style: SegmentedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              selectedForegroundColor: AppTheme.background,
              selectedBackgroundColor: accent,
            ),
          ),

          const SizedBox(height: 10),

          // Helper text or override-active notice
          Text(
            state.override == NightModeOverride.auto
                ? 'Switches automatically based on lighting.'
                : 'Manual override active. Tap Auto to resume automatic detection.',
            style: TextStyle(
              color: state.override == NightModeOverride.auto
                  ? AppTheme.textTertiary
                  : AppTheme.warning.withOpacity(0.9),
              fontSize: 12,
            ),
          ),

          if (isStale) ...[
            const SizedBox(height: 8),
            Text(
              'Robot offline — change will apply when reconnected.',
              style: TextStyle(
                color: AppTheme.warning.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _luxLine(double? lux) {
    final label = NightModeState.luxLabel(lux);
    if (lux == null) return 'Lighting: $label';
    return '${lux.toStringAsFixed(1)} lux — $label';
  }

  String _lastChangedLine(DateTime ts, bool isNight) {
    final ago = DateTime.now().difference(ts);
    final modeWord = isNight ? 'night vision' : 'day mode';
    if (ago.inSeconds < 60) {
      return 'Switched to $modeWord ${ago.inSeconds}s ago';
    }
    if (ago.inMinutes < 60) {
      return 'Switched to $modeWord ${ago.inMinutes}m ago';
    }
    if (ago.inHours < 24) {
      return 'Switched to $modeWord ${ago.inHours}h ago';
    }
    return 'Switched to $modeWord ${ago.inDays}d ago';
  }
}
