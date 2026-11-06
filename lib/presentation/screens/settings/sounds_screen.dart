import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sound_catalog.dart';
import '../../../domain/providers/sounds_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Settings → Advanced → Sounds. Every sound id the robot plays, grouped,
/// each with Replace-from-phone (and Restore factory when customised).
class SoundsScreen extends ConsumerStatefulWidget {
  const SoundsScreen({super.key});

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  static const _maxBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(soundsProvider.notifier).load();
    });
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _replace(SoundSlot slot) async {
    final l = context.l10n;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;
    if (file.size > _maxBytes) {
      _snack(l.soundsReplaceFailed(l.uploadErrTooLarge), error: true);
      return;
    }
    final err = await ref
        .read(soundsProvider.notifier)
        .replace(slot.id, file.path!, file.name);
    if (err == null) {
      _snack(l.soundsReplaced(slot.id));
    } else {
      _snack(l.soundsReplaceFailed(err), error: true);
    }
  }

  Future<void> _restore(SoundSlot slot) async {
    final l = context.l10n;
    final err = await ref.read(soundsProvider.notifier).resetOne(slot.id);
    if (err == null) {
      _snack(l.settingsResetSoundsDone);
    } else {
      _snack(l.settingsResetSoundsFailed(err), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(soundsProvider);
    final l = context.l10n;

    final groups = <(SoundGroup, String)>[
      (SoundGroup.greeting, l.soundGroupGreeting),
      (SoundGroup.treat, l.soundGroupTreat),
      (SoundGroup.cue, l.soundGroupCue),
      (SoundGroup.alert, l.soundGroupAlert),
      (SoundGroup.sgLevel, l.soundGroupSgLevel),
      (SoundGroup.music, l.soundGroupMusic),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.soundsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () => ref.read(soundsProvider.notifier).load(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              state.fromRobot ? l.soundsCatalogFromRobot : l.soundsCatalogDefault,
              style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(state.error!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final (group, title) in groups)
                  if (state.byGroup(group).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    for (final slot in state.byGroup(group))
                      _SoundRow(
                        slot: slot,
                        busy: state.busyId == slot.id,
                        progress: state.progress,
                        disabled: state.busyId != null || state.resettingAll,
                        onReplace: () => _replace(slot),
                        onRestore: slot.custom ? () => _restore(slot) : null,
                      ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  final SoundSlot slot;
  final bool busy;
  final double progress;
  final bool disabled;
  final VoidCallback onReplace;
  final VoidCallback? onRestore;

  const _SoundRow({
    required this.slot,
    required this.busy,
    required this.progress,
    required this.disabled,
    required this.onReplace,
    this.onRestore,
  });

  /// "sg_level_2" → "Sg level 2" when the robot sent no label.
  String _label() {
    if (slot.label != null && slot.label!.isNotEmpty) return slot.label!;
    final words = slot.id.replaceAll('_', ' ');
    return words.isEmpty ? slot.id : words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: Icon(
        slot.custom ? Icons.graphic_eq : Icons.music_note_outlined,
        color: slot.custom ? AppTheme.accent : AppTheme.textTertiary,
        size: 20,
      ),
      title: Text(_label(),
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
      subtitle: Row(
        children: [
          Text(slot.id,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppTheme.textTertiary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: (slot.custom ? AppTheme.accent : AppTheme.textTertiary)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              slot.custom ? l.soundsCustom : l.soundsFactory,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: slot.custom ? AppTheme.accent : AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
      trailing: busy
          ? SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress > 0 && progress < 1 ? progress : null,
                  ),
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRestore != null)
                  IconButton(
                    tooltip: l.soundsRestoreOne,
                    icon: const Icon(Icons.restore, size: 20),
                    color: AppTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                    onPressed: disabled ? null : onRestore,
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primary,
                  ),
                  onPressed: disabled ? null : onReplace,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(l.soundsReplace,
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
    );
  }
}
