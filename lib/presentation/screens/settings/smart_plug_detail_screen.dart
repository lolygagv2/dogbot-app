import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/providers/smart_plug_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Calming diffuser plug — Detail. Manual switch, Silent Guardian trigger
/// level, auto-off duration, change / remove.
class SmartPlugDetailScreen extends ConsumerStatefulWidget {
  const SmartPlugDetailScreen({super.key});

  @override
  ConsumerState<SmartPlugDetailScreen> createState() =>
      _SmartPlugDetailScreenState();
}

class _SmartPlugDetailScreenState extends ConsumerState<SmartPlugDetailScreen> {
  static const _triggerLevels = [1, 2, 3, 4];
  static const _autoOffMinutes = [30, 60, 120, 240];

  Timer? _statusTimer;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Robot is the truth: re-read status every 60 s while the screen is open.
    _statusTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.read(smartPlugProvider.notifier).refreshStatus();
    });
    // Local countdown between refreshes (display is minute-granular).
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final at = ref.read(smartPlugProvider).status?.autoOffAt;
      if (at == null) return;
      if (!at.isAfter(DateTime.now())) {
        // Timer ran out — the robot has (or is about to have) switched it off.
        ref.read(smartPlugProvider.notifier).refreshStatus();
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(smartPlugProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _showError(String? code) {
    if (code == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(smartPlugErrorLabel(context.l10n, code)),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _pickOption({
    required String title,
    required List<int> options,
    required int current,
    required String Function(int) label,
    required Future<String?> Function(int) apply,
  }) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final w = sheetContext.wimz;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              for (final o in options)
                ListTile(
                  title: Text(label(o)),
                  trailing: o == current
                      ? Icon(Icons.check, color: w.ink)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(o),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == current || !mounted) return;
    _showError(await apply(picked));
  }

  Future<void> _confirmRemove(String alias) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.smartPlugRemoveConfirmTitle),
        content: Text(l.smartPlugRemoveConfirmBody(alias)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await ref.read(smartPlugProvider.notifier).remove();
    if (!mounted) return;
    if (err != null) {
      _showError(err);
      return;
    }
    // Back to the entry row, which now reads "Not set up".
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final s = ref.watch(smartPlugProvider);
    final notifier = ref.read(smartPlugProvider.notifier);
    final status = s.status;

    if (status == null || !status.configured) {
      // Opened before status landed, or the plug was removed elsewhere.
      return Scaffold(
        appBar: AppBar(title: Text(l.smartPlugTitle)),
        body: Center(
          child: s.loading
              ? const CircularProgressIndicator(strokeWidth: 2.5)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status == null
                            ? l.smartPlugErrGeneric
                            : l.smartPlugNotSetUp,
                        style: TextStyle(color: w.inkMuted),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: status == null
                            ? notifier.refreshStatus
                            : () => context
                                .pushReplacement('/settings/smart-plug/setup'),
                        child: Text(status == null
                            ? l.retry
                            : l.smartPlugSetupTitle),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final alias = status.alias ?? l.smartPlugTitle;
    final reachable = status.reachable;

    // Caption under the switch. Unavailable is a normal state: muted text,
    // no red, no alert, no retry loop.
    String? caption;
    if (!reachable) {
      caption = l.smartPlugUnavailable;
    } else if (status.on && status.ownedByRobot) {
      final at = status.autoOffAt;
      if (at != null) {
        final secs = at.difference(DateTime.now()).inSeconds;
        final mins = secs <= 0 ? 1 : (secs / 60).ceil();
        caption = l.smartPlugRobotOwned(smartPlugDurationLabel(l, mins));
      }
    } else if (status.on) {
      caption = l.smartPlugStaysOn;
    }

    return Scaffold(
      appBar: AppBar(title: Text(alias)),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: Icon(
              status.on && reachable ? Icons.power : Icons.power_outlined,
              color: reachable ? w.ink : w.inkMuted,
            ),
            title: Text(
              l.smartPlugSwitch,
              style: TextStyle(color: reachable ? w.ink : w.inkMuted),
            ),
            subtitle: caption == null
                ? null
                : Text(caption, style: TextStyle(color: w.inkMuted)),
            value: status.on && reachable,
            onChanged: (!reachable || s.busy)
                ? null
                : (v) async => _showError(await notifier.setOn(v)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(l.smartPlugTurnOnAt),
            trailing: _ValueChip(l.smartPlugLevel(status.triggerLevel)),
            enabled: !s.busy,
            onTap: () => _pickOption(
              title: l.smartPlugTurnOnAt,
              options: _triggerLevels,
              current: status.triggerLevel,
              label: l.smartPlugLevel,
              apply: notifier.setTriggerLevel,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.smartPlugTurnOffAfter),
            trailing: _ValueChip(
                smartPlugDurationLabel(l, status.autoOffMinutes)),
            enabled: !s.busy,
            onTap: () => _pickOption(
              title: l.smartPlugTurnOffAfter,
              options: _autoOffMinutes,
              current: status.autoOffMinutes,
              label: (m) => smartPlugDurationLabel(l, m),
              apply: notifier.setAutoOffMinutes,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: w.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.smartPlugHelp,
                    style: TextStyle(
                        color: w.inkMuted, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l.smartPlugChange),
            trailing: const Icon(Icons.chevron_right),
            enabled: !s.busy,
            onTap: () => context.push(
              '/settings/smart-plug/setup',
              extra: const {'fromDetail': true},
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: Text(l.smartPlugRemove),
            enabled: !s.busy,
            onTap: () => _confirmRemove(alias),
          ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String text;
  const _ValueChip(this.text);

  @override
  Widget build(BuildContext context) {
    final w = context.wimz;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(color: w.inkMuted, fontSize: 14)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: w.inkMuted),
      ],
    );
  }
}
