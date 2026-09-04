import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/telemetry.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../theme/app_theme.dart';

/// Treat counter indicator for the AppBar.
/// Shows treats REMAINING out of the fixed 44-slot carousel ("37/44").
/// B160 (2026-09-04): remaining is the one figure rendered — it follows
/// whichever counter field the latest robot frame carried (periodic status
/// frames carry treats_remaining; acks carry treats_given), so the chip can
/// no longer latch on a stale value. Capacity is a hard physical constant.
/// Tap to open management sheet (2-tap reset for expo demos).
class TreatCounterIndicator extends ConsumerWidget {
  const TreatCounterIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(treatsRemainingProvider); // null = no data yet

    final Color color;
    final String label;
    if (remaining == null) {
      color = AppTheme.textTertiary;
      label = '—'; // em-dash
    } else {
      if (remaining == 0) {
        color = AppTheme.error;
      } else if (remaining < 5) {
        color = AppTheme.warning;
      } else {
        color = AppTheme.accent;
      }
      label = '$remaining/$kTreatCapacity';
    }

    return GestureDetector(
      onTap: () => _showTreatSheet(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.cookie, color: color, size: 20),
              // Warning dot when low but not empty
              if (remaining != null && remaining > 0 && remaining < 5)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showTreatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _TreatManagementSheet(),
    );
  }
}

/// Bottom sheet for managing the treat counter — full-refill reset, jam
/// clear, or "Treats loaded" for a partial load. No capacity control: the
/// carousel is always 44 slots. Commands are fire-and-forget; the robot's
/// treat_counter_ack (carrying real values) updates the UI via telemetry.
class _TreatManagementSheet extends ConsumerStatefulWidget {
  const _TreatManagementSheet();

  @override
  ConsumerState<_TreatManagementSheet> createState() =>
      _TreatManagementSheetState();
}

class _TreatManagementSheetState extends ConsumerState<_TreatManagementSheet> {
  final _countController = TextEditingController();
  bool _isClearing = false;

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(treatsRemainingProvider);

    final headline =
        remaining != null ? '$remaining of $kTreatCapacity' : '—';
    final bool isEmpty = remaining == 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Treats: $headline',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (remaining != null) ...[
              const SizedBox(height: 4),
              Text(
                isEmpty ? 'Empty — refill needed' : 'treats remaining',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w400,
                  color: isEmpty ? AppTheme.error : AppTheme.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Refilled → zero the given counter (full 44)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(treatControlProvider).resetCount();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Refilled — Reset Counter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Clear Jam button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isClearing
                    ? null
                    : () {
                        setState(() => _isClearing = true);
                        ref.read(treatControlProvider).clearJam();
                        // Show brief "Clearing..." state then dismiss
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        });
                      },
                icon: _isClearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : const Icon(Icons.build_circle_outlined),
                label: Text(
                  _isClearing ? 'Clearing...' : 'Clear Jam',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Partial load: single "Treats loaded" field (max 44)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Treats loaded (max $kTreatCapacity)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final value = int.tryParse(_countController.text);
                    if (value != null && value >= 0) {
                      ref
                          .read(treatControlProvider)
                          .setCount(value.clamp(0, kTreatCapacity));
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLighter,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
