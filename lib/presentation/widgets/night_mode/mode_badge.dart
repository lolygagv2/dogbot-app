import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/night_mode_state.dart';
import '../../../domain/providers/night_mode_provider.dart';
import '../../theme/app_theme.dart';

/// Compact day/night badge overlaid on the live video. Display-only — the
/// override control lives in Settings → Night Vision per Build 100 scope.
///
/// Visual states (per nightvision.md §3A):
///   day   → subtle sun, low-emphasis (doesn't draw the eye)
///   night → prominent moon, cool border + glow
///   stale → greyed with a warning dot
///
/// Renders nothing until the first heartbeat arrives.
class ModeBadge extends ConsumerWidget {
  const ModeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nightModeProvider);
    final isStale = ref.watch(nightModeIsStaleProvider);
    if (state == null) return const SizedBox.shrink();

    final isNight = state.currentMode == DayNight.night;
    final accent = isNight ? AppTheme.behaviorLying : AppTheme.textSecondary;
    final bg = isNight
        ? AppTheme.background.withOpacity(0.75)
        : AppTheme.background.withOpacity(0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isStale
              ? AppTheme.textTertiary.withOpacity(0.4)
              : accent.withOpacity(isNight ? 0.6 : 0.25),
          width: 1,
        ),
        boxShadow: isNight && !isStale
            ? [
                BoxShadow(
                  color: accent.withOpacity(0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNight ? Icons.nights_stay : Icons.wb_sunny,
            color: isStale ? AppTheme.textTertiary : accent,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isNight ? 'IR night view' : 'Day',
            style: TextStyle(
              color: isStale ? AppTheme.textTertiary : accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (isStale) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.warning_amber_rounded,
              size: 12,
              color: AppTheme.warning.withOpacity(0.8),
            ),
          ],
        ],
      ),
    );
  }
}
