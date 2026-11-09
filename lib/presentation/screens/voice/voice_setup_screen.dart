import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/dog_profile.dart';
import '../../../data/models/voice_command.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/voice_commands_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

bool get _isMobilePlatform {
  try {
    return Platform.isIOS || Platform.isAndroid;
  } catch (e) {
    return false;
  }
}

/// Voice command recording setup screen
class VoiceSetupScreen extends ConsumerStatefulWidget {
  final String? dogId;

  const VoiceSetupScreen({super.key, this.dogId});

  @override
  ConsumerState<VoiceSetupScreen> createState() => _VoiceSetupScreenState();
}

class _VoiceSetupScreenState extends ConsumerState<VoiceSetupScreen> {
  bool _isSyncing = false;

  DogProfile? get _dog {
    if (widget.dogId != null) {
      return ref.watch(dogProfileProvider(widget.dogId!));
    }
    return ref.watch(selectedDogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dog = _dog;

    if (dog == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.voiceTitle)),
        body: Center(child: Text(context.l10n.voiceNoDogSelected)),
      );
    }

    final voiceCommands = ref.watch(voiceCommandsProvider(dog.id));
    final notifier = ref.read(voiceCommandsProvider(dog.id).notifier);

    final hasRecordings =
        voiceCommands.commands.values.any((c) => c.localPath != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.voiceTitle),
        actions: [
          if (hasRecordings)
            IconButton(
              icon: const Icon(Icons.settings_backup_restore),
              tooltip: context.l10n.voiceResetTooltip,
              onPressed: () => _resetToDefault(dog.name, notifier),
            ),
          TextButton.icon(
            onPressed: _isSyncing ? null : () => _syncAll(notifier),
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, size: 20),
            label: Text(context.l10n.voiceSyncAll),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header explanation
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.mic,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.voiceIntro(dog.name),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mobile-only notice (only show on non-mobile platforms)
          if (!_isMobilePlatform)
            Container(
              padding: const EdgeInsets.all(12),
              color: context.wimz.surfaceRaised,
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: context.wimz.inkMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.voiceMobileOnlyBanner,
                      style: TextStyle(color: context.wimz.inkMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Progress indicator
          _buildProgressBar(notifier),

          // Command list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: VoiceCommandType.values.length,
              itemBuilder: (context, index) {
                final commandType = VoiceCommandType.values[index];
                final command = voiceCommands.commands[commandType.id];

                return _CommandTile(
                  commandType: commandType,
                  command: command,
                  dogName: dog.name,
                  onRecord: () => _showRecordDialog(context, commandType, dog.name, notifier),
                  onDelete: command?.localPath != null
                      ? () => _deleteCommand(commandType.id, notifier)
                      : null,
                  onSync: command?.localPath != null && !(command?.isSynced ?? true)
                      ? () => _syncCommand(commandType.id, notifier)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VoiceCommandsNotifier notifier) {
    final recorded = notifier.recordedCount;
    final total = VoiceCommandType.values.length;
    final synced = notifier.syncedCount;
    final progress = total > 0 ? recorded / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.voiceRecordedProgress(recorded, total),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                context.l10n.voiceSyncedCount(synced),
                style: TextStyle(
                  color: synced == recorded && recorded > 0
                      ? context.wimz.ink
                      : context.wimz.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.wimz.surfaceSunken,
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordDialog(
    BuildContext context,
    VoiceCommandType commandType,
    String dogName,
    VoiceCommandsNotifier notifier,
  ) {
    if (!_isMobilePlatform) {
      // Show "not available" dialog on non-mobile platforms
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.phone_android),
              const SizedBox(width: 8),
              Text(context.l10n.voiceMobileRequiredTitle),
            ],
          ),
          content: Text(context.l10n.voiceMobileRequiredBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    // On mobile: show actual recording dialog
    final displayLabel = commandType == VoiceCommandType.name
        ? '"$dogName"'
        : commandType.localizedLabel(context.l10n);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordingDialog(
        commandId: commandType.id,
        commandLabel: displayLabel,
        notifier: notifier,
      ),
    );
  }

  Future<void> _deleteCommand(String commandId, VoiceCommandsNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.voiceDeleteRecordingTitle),
        content: Text(context.l10n.voiceDeleteRecordingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.delete_outline,
                size: 18, color: Theme.of(context).colorScheme.error),
            label: Text(context.l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.deleteCommand(commandId);
    }
  }

  Future<void> _syncCommand(String commandId, VoiceCommandsNotifier notifier) async {
    final success = await notifier.syncCommand(commandId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? context.l10n.voiceCommandSynced : context.l10n.voiceSyncFailed)),
      );
    }
  }

  Future<void> _resetToDefault(
    String dogName,
    VoiceCommandsNotifier notifier,
  ) async {
    final count = notifier.recordedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.voiceResetTitle),
        content: Text(context.l10n.voiceResetBody(count, dogName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.settings_backup_restore,
                size: 18, color: Theme.of(context).colorScheme.error),
            label: Text(context.l10n.voiceResetAction,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.resetAllToDefault();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.voiceResetDone),
          ),
        );
      }
    }
  }

  Future<void> _syncAll(VoiceCommandsNotifier notifier) async {
    setState(() => _isSyncing = true);
    // force: the manual button re-uploads everything recorded, healing
    // relay-side file loss even when the app believed it was synced.
    final count = await notifier.syncAll(force: true);
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voiceSyncedToRobot(count))),
      );
    }
  }
}

/// Individual command tile
class _CommandTile extends StatelessWidget {
  final VoiceCommandType commandType;
  final VoiceCommand? command;
  final String dogName;
  final VoidCallback onRecord;
  final VoidCallback? onDelete;
  final VoidCallback? onSync;

  const _CommandTile({
    required this.commandType,
    this.command,
    required this.dogName,
    required this.onRecord,
    this.onDelete,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final isRecorded = command?.localPath != null;
    final isSynced = command?.isSynced ?? false;

    final displayLabel = commandType == VoiceCommandType.name
        ? '"$dogName"'
        : commandType.localizedLabel(context.l10n);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecorded
                ? Theme.of(context).colorScheme.primary
                : context.wimz.surfaceSunken,
          ),
          child: Icon(
            isRecorded
                ? (isSynced ? Icons.cloud_done : Icons.check)
                : Icons.mic_none,
            color: isRecorded
                ? Theme.of(context).colorScheme.onPrimary
                : context.wimz.inkMuted,
            size: 20,
          ),
        ),
        title: Text(
          displayLabel,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isRecorded
              ? (isSynced ? context.l10n.voiceRecordedSynced : context.l10n.voiceRecordedTapToSync)
              : context.l10n.voiceNotRecorded,
          style: TextStyle(
            fontSize: 12,
            color: isRecorded
                ? Theme.of(context).colorScheme.primary
                : context.wimz.inkMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecorded) ...[
              if (!isSynced)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  onPressed: onSync,
                  tooltip: context.l10n.voiceSyncToRobotTooltip,
                ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: context.wimz.ink),
                onPressed: onDelete,
                tooltip: context.l10n.delete,
              ),
            ],
            IconButton(
              icon: Icon(
                isRecorded ? Icons.refresh : Icons.mic,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onRecord,
              tooltip: isRecorded ? context.l10n.voiceReRecord : context.l10n.voiceRecord,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recording dialog for voice commands on mobile
class _RecordingDialog extends StatefulWidget {
  final String commandId;
  final String commandLabel;
  final VoiceCommandsNotifier notifier;

  const _RecordingDialog({
    required this.commandId,
    required this.commandLabel,
    required this.notifier,
  });

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  bool _isRecording = false;
  bool _isDone = false;
  String? _error;
  Timer? _durationTimer;
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    print('RecordDialog: Starting recording for ${widget.commandId}');
    final success = await widget.notifier.startRecording(widget.commandId);
    print('RecordDialog: startRecording returned $success');

    if (!mounted) return;

    if (success) {
      setState(() {
        _isRecording = true;
        _elapsedMs = 0;
      });

      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) {
          setState(() => _elapsedMs += 100);
        }
      });
    } else {
      setState(() {
        _error = context.l10n.voiceStartFailed;
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    print('RecordDialog: Stopping recording');

    final command = await widget.notifier.stopRecording();
    print('RecordDialog: stopRecording returned ${command != null ? "success" : "null"}');

    if (!mounted) return;

    if (command != null) {
      setState(() {
        _isRecording = false;
        _isDone = true;
      });
    } else {
      setState(() {
        _isRecording = false;
        _error = context.l10n.voiceRecordingFailed;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _durationTimer?.cancel();
    if (_isRecording) {
      await widget.notifier.cancelRecording();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_elapsedMs / 1000).toStringAsFixed(1);

    return AlertDialog(
      title: Text(_isDone ? context.l10n.voiceSavedTitle : context.l10n.voiceRecordTitle(widget.commandLabel)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Icon(Icons.error,
                color: Theme.of(context).colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ] else if (_isDone) ...[
            Icon(Icons.check_circle, color: context.wimz.ink, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.voiceRecordedSuccess),
          ] else if (_isRecording) ...[
            Icon(Icons.mic, color: context.wimz.ink, size: 48),
            const SizedBox(height: 12),
            Text(
              context.l10n.voiceSeconds(seconds),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.voiceSayClearly),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.l10n.voicePreparingMic),
          ],
        ],
      ),
      actions: [
        if (_error != null || _isDone)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isDone ? context.l10n.done : context.l10n.close),
          ),
        if (_error != null && !_isDone)
          TextButton(
            onPressed: () {
              setState(() => _error = null);
              _startRecording();
            },
            child: Text(context.l10n.retry),
          ),
        if (_isRecording) ...[
          TextButton(
            onPressed: _cancelRecording,
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            label: Text(context.l10n.voiceStop),
          ),
        ],
      ],
    );
  }
}
