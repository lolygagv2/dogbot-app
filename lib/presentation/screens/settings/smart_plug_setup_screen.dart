import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/smart_plug.dart';
import '../../../domain/providers/smart_plug_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Calming diffuser plug — Setup. The robot scans its own WiFi for TP-Link
/// Kasa plugs; the user taps one to bind it.
///
/// [fromDetail] is true when opened via "Change plug": a successful pick pops
/// back to the Detail screen already on the stack instead of pushing a new one.
class SmartPlugSetupScreen extends ConsumerStatefulWidget {
  final bool fromDetail;
  const SmartPlugSetupScreen({super.key, this.fromDetail = false});

  @override
  ConsumerState<SmartPlugSetupScreen> createState() =>
      _SmartPlugSetupScreenState();
}

class _SmartPlugSetupScreenState extends ConsumerState<SmartPlugSetupScreen> {
  String? _pickingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(smartPlugProvider.notifier).scan();
    });
  }

  Future<void> _pick(SmartPlugDevice plug) async {
    if (_pickingId != null) return;
    setState(() => _pickingId = plug.deviceId);
    final notifier = ref.read(smartPlugProvider.notifier);
    final err = await notifier.selectPlug(plug.deviceId);
    if (!mounted) return;
    setState(() => _pickingId = null);
    if (err == null) {
      if (widget.fromDetail) {
        context.pop();
      } else {
        context.pushReplacement('/settings/smart-plug');
      }
      return;
    }
    final l = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(smartPlugErrorLabel(l, err)),
        behavior: SnackBarBehavior.floating,
        action: err == SmartPlugError.plugNotFound
            ? SnackBarAction(label: l.smartPlugRescan, onPressed: notifier.scan)
            : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final s = ref.watch(smartPlugProvider);
    final plugs = s.plugs;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.smartPlugSetupTitle),
        actions: [
          if (!s.scanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l.smartPlugRescan,
              onPressed: ref.read(smartPlugProvider.notifier).scan,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l.smartPlugIntro,
              style: TextStyle(color: w.inkMuted, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          if (s.scanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 16),
                  Text(l.smartPlugScanning,
                      style: TextStyle(color: w.inkMuted)),
                ],
              ),
            )
          else if (plugs == null || plugs.isEmpty)
            // Empty list is a normal result, not an error: same calm layout
            // whether nothing answered or the scan itself didn't come back.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                children: [
                  Icon(Icons.power_off_outlined, size: 40, color: w.inkMuted),
                  const SizedBox(height: 12),
                  Text(
                    s.scanFailed ? l.smartPlugErrGeneric : l.smartPlugNoneFound,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: w.ink, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l.smartPlugRescan),
                    onPressed: ref.read(smartPlugProvider.notifier).scan,
                  ),
                ],
              ),
            )
          else
            for (final plug in plugs)
              _PlugRow(
                plug: plug,
                picking: _pickingId == plug.deviceId,
                enabled: _pickingId == null,
                onTap: () => _pick(plug),
              ),
        ],
      ),
    );
  }
}

class _PlugRow extends StatelessWidget {
  final SmartPlugDevice plug;
  final bool picking;
  final bool enabled;
  final VoidCallback onTap;

  const _PlugRow({
    required this.plug,
    required this.picking,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final model = plug.model;
    final sub = [
      if (model != null) model,
      if (plug.selected) l.smartPlugCurrent,
    ].join(' · ');

    return ListTile(
      enabled: enabled,
      leading: Icon(
        plug.selected ? Icons.check_circle : Icons.power_outlined,
        color: plug.selected ? w.ink : w.inkMuted,
      ),
      title: Text(plug.alias),
      subtitle: sub.isEmpty
          ? null
          : Text(sub, style: TextStyle(color: w.inkMuted)),
      trailing: picking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: w.surfaceSunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                plug.on ? l.on : l.off,
                style: TextStyle(
                  color: plug.on ? w.ink : w.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}
