import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../theme/app_theme.dart';

/// Treat counter indicator for the AppBar — shows remaining treats with color tiers.
/// Tap to open management sheet (2-tap reset for expo demos).
class TreatCounterIndicator extends ConsumerWidget {
  const TreatCounterIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(treatsRemainingProvider); // null = no data yet

    // Color tiers
    final Color color;
    final String label;
    if (count == null) {
      color = AppTheme.textTertiary;
      label = '\u2014'; // em-dash
    } else if (count <= 0) {
      color = AppTheme.textTertiary;
      label = '0 (refill)';
    } else if (count <= 5) {
      color = AppTheme.warning;
      label = '$count left';
    } else {
      color = AppTheme.accent;
      label = '$count left';
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
              if (count != null && count > 0 && count < 5)
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

/// Bottom sheet for managing treat counter — reset or set custom count.
/// Commands are fire-and-forget; UI updates when next telemetry cycle confirms.
class _TreatManagementSheet extends ConsumerStatefulWidget {
  const _TreatManagementSheet();

  @override
  ConsumerState<_TreatManagementSheet> createState() =>
      _TreatManagementSheetState();
}

class _TreatManagementSheetState extends ConsumerState<_TreatManagementSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(treatsRemainingProvider);
    final displayCount = count == null
        ? '\u2014'
        : count <= 0
            ? '0 (refill needed)'
            : '$count';

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
              'Treats Remaining: $displayCount',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            // Reset to Full — the 2-tap expo flow
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
                  'Reset to Full',
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
            const SizedBox(height: 16),
            // Set custom count
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Custom count',
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
                    final value = int.tryParse(_controller.text);
                    if (value != null && value >= 0) {
                      ref.read(treatControlProvider).setCount(value);
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
