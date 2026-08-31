import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../theme/app_theme.dart';

/// Treat counter indicator for the AppBar.
/// Robot 8e8c91c (2026-08-30): the counter counts UP — treats_given since
/// last load/reset, beam-confirmed. Primary figure is "X of 44 given";
/// low/empty tiers derive from treats_remaining (never negative).
/// Tap to open management sheet (2-tap reset for expo demos).
class TreatCounterIndicator extends ConsumerWidget {
  const TreatCounterIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final given = ref.watch(treatsGivenProvider); // null = no data yet
    final capacity = ref.watch(treatCapacityProvider);
    final remaining = ref.watch(treatsRemainingProvider); // null = no data yet

    // Color tiers from remaining; label prefers the given/capacity figure.
    final Color color;
    final String label;
    if (given == null && remaining == null) {
      color = AppTheme.textTertiary;
      label = '—'; // em-dash
    } else {
      if (remaining == 0) {
        color = AppTheme.error;
      } else if (remaining != null && remaining < 5) {
        color = AppTheme.warning;
      } else {
        color = AppTheme.accent;
      }
      if (given != null) {
        label = '$given/$capacity given';
      } else {
        // Pre-8e8c91c firmware: only remaining is known.
        label = remaining == 0 ? '0 (refill)' : '$remaining left';
      }
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

/// Bottom sheet for managing the treat counter — refill reset, jam clear, or
/// set loaded count (with optional capacity when the carousel size differs).
/// Commands are fire-and-forget; the robot's treat_counter_ack (carrying real
/// values — a reset does NOT imply zero) updates the UI via telemetry state.
class _TreatManagementSheet extends ConsumerStatefulWidget {
  const _TreatManagementSheet();

  @override
  ConsumerState<_TreatManagementSheet> createState() =>
      _TreatManagementSheetState();
}

class _TreatManagementSheetState extends ConsumerState<_TreatManagementSheet> {
  final _countController = TextEditingController();
  final _capacityController = TextEditingController();
  bool _isClearing = false;

  @override
  void dispose() {
    _countController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final given = ref.watch(treatsGivenProvider);
    final capacity = ref.watch(treatCapacityProvider);
    final remaining = ref.watch(treatsRemainingProvider);

    final String headline;
    if (given != null) {
      headline = '$given of $capacity given';
    } else if (remaining != null) {
      headline = '$remaining remaining';
    } else {
      headline = '—';
    }
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
            if (given != null && remaining != null) ...[
              const SizedBox(height: 4),
              Text(
                isEmpty ? 'Empty — refill needed' : '$remaining remaining',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w400,
                  color: isEmpty ? AppTheme.error : AppTheme.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Refilled → zero the given counter (capacity is kept robot-side)
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
            // Partial load: set loaded count + optional capacity override
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Loaded',
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Capacity ($capacity)',
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
                    final newCapacity =
                        int.tryParse(_capacityController.text);
                    if (value != null && value >= 0) {
                      ref
                          .read(treatControlProvider)
                          .setCount(value, capacity: newCapacity);
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
