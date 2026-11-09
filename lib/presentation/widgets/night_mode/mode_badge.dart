import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/night_mode_state.dart';
import '../../../domain/providers/night_mode_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Compact day/night badge overlaid on the live video. Display-only — the
/// override control lives in Settings → Night Vision per Build 100 scope.
///
/// Visual states (per nightvision.md §3A), on the always-dark video ground:
///   day   → subtle sun, low-emphasis (doesn't draw the eye)
///   night → prominent moon, stronger scrim + edge
///   stale → dimmed with a warning icon
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
    final w = context.wimz;
    final fg = isStale
        ? w.onVideo.withValues(alpha: 0.5)
        : (isNight ? w.onVideo : w.onVideo.withValues(alpha: 0.8));
    final bg = w.scrim(isNight ? 0.75 : 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNight && !isStale
              ? w.onVideo.withValues(alpha: 0.6)
              : w.lineOnVideo,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNight ? Icons.nights_stay : Icons.wb_sunny,
            color: fg,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isNight
                ? context.l10n.nightVisionBadgeNight
                : context.l10n.nightVisionBadgeDay,
            style: TextStyle(
              color: fg,
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
              color: w.onVideo.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );
  }
}
