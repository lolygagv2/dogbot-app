import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/silent_guardian_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// "Intervention level" slider for Silent Guardian fast-escalation.
///
/// One labeled slider with `Off` at the far left and the active range
/// 10–90 BPM on the rest (lower BPM = more aggressive intervention).
/// The robot accepts any integer; we quantise to 0/10/20…/90 anchors via
/// `divisions: 9` so the slider feels notched without limiting expressivity.
class InterventionLevelSection extends ConsumerStatefulWidget {
  const InterventionLevelSection({super.key});

  @override
  ConsumerState<InterventionLevelSection> createState() =>
      _InterventionLevelSectionState();
}

class _InterventionLevelSectionState
    extends ConsumerState<InterventionLevelSection> {
  double? _dragValue;
  String? _lastShownError;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(silentGuardianProvider);
    final l = context.l10n;
    final w = context.wimz;
    final cs = Theme.of(context).colorScheme;

    // Surface acked errors as a transient toast — once per distinct error.
    if (state.lastError != null && state.lastError != _lastShownError) {
      _lastShownError = state.lastError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: cs.onError),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.sgError('${state.lastError}'),
                    style: TextStyle(color: cs.onError),
                  ),
                ),
              ],
            ),
            backgroundColor: cs.error,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    } else if (state.lastError == null) {
      _lastShownError = null;
    }

    final current = (_dragValue ?? state.interventionLevel.toDouble()).round();
    final isOff = current == 0;
    final accent = isOff ? w.inkMuted : cs.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOff ? Icons.shield_outlined : Icons.shield,
                color: accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.sgInterventionLevel,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.sgInterventionSubtitle,
                      style: TextStyle(
                        color: w.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: w.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOff ? l.off : l.sgBpm(current),
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: w.surfaceSunken,
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.2),
              valueIndicatorColor: accent,
              valueIndicatorTextStyle: TextStyle(
                color: cs.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Slider(
              value: (_dragValue ?? state.interventionLevel.toDouble())
                  .clamp(0.0, 90.0),
              min: 0,
              max: 90,
              divisions: 9,
              label: isOff ? l.off : l.sgBpm(current),
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                final next = v.round();
                setState(() => _dragValue = null);
                ref
                    .read(silentGuardianProvider.notifier)
                    .setInterventionLevel(next);
              },
            ),
          ),

          // Anchor labels — Off / Aggressive / Tolerant
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.off,
                  style: TextStyle(
                    color: w.inkMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  l.sgAggressive,
                  style: TextStyle(
                    color: w.inkMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  l.sgTolerant,
                  style: TextStyle(
                    color: w.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _helperText(l, current),
            style: TextStyle(
              color: w.inkMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _helperText(AppLocalizations l, int bpm) {
    if (bpm == 0) return l.sgHelperOff;
    if (bpm <= 15) return l.sgHelperLow;
    if (bpm <= 45) return l.sgHelperMid;
    return l.sgHelperHigh;
  }
}
