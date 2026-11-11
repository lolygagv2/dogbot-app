import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/providers/connection_mode_provider.dart';
import '../../../domain/providers/smart_plug_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Settings → Silent Guardian entry row for the calming diffuser plug.
///
/// Asks the robot for `status` each time Silent Guardian settings open (and
/// again when the connection comes up). Not set up → Setup; set up → Detail.
class SmartPlugTile extends ConsumerStatefulWidget {
  const SmartPlugTile({super.key});

  @override
  ConsumerState<SmartPlugTile> createState() => _SmartPlugTileState();
}

class _SmartPlugTileState extends ConsumerState<SmartPlugTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(smartPlugProvider.notifier).refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.wimz;
    final s = ref.watch(smartPlugProvider);
    final status = s.status;

    ref.listen<bool>(isConnectedAnyModeProvider, (prev, next) {
      if (next && prev != true) {
        ref.read(smartPlugProvider.notifier).refreshStatus();
      }
    });

    final String subtitle;
    if (status == null) {
      subtitle = s.loading
          ? l.smartPlugChecking
          : (s.statusFailed ? l.smartPlugErrGeneric : l.smartPlugNotSetUp);
    } else if (!status.configured) {
      subtitle = l.smartPlugNotSetUp;
    } else {
      final stateLabel = !status.reachable
          ? l.smartPlugUnavailableShort
          : (status.on ? l.on : l.off);
      final alias = status.alias;
      subtitle = alias == null
          ? stateLabel
          : l.smartPlugRowState(alias, stateLabel);
    }

    return ListTile(
      leading: const Icon(Icons.power_outlined),
      title: Text(l.smartPlugTitle),
      subtitle: Text(subtitle, style: TextStyle(color: w.inkMuted)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (status == null) {
          // No answer yet — ask again rather than guess which screen fits.
          ref.read(smartPlugProvider.notifier).refreshStatus();
          if (s.statusFailed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l.smartPlugErrGeneric)));
          }
          return;
        }
        context.push(status.configured
            ? '/settings/smart-plug'
            : '/settings/smart-plug/setup');
      },
    );
  }
}
