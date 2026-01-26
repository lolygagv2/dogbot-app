import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/dog_profile.dart';
import '../../../data/models/voice_command.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/voice_commands_provider.dart';
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
        appBar: AppBar(title: const Text('Voice Commands')),
        body: const Center(child: Text('No dog selected')),
      );
    }

    final voiceCommands = ref.watch(voiceCommandsProvider(dog.id));
    final notifier = ref.read(voiceCommandsProvider(dog.id).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Commands'),
        actions: [
          TextButton.icon(
            onPressed: _isSyncing ? null : () => _syncAll(notifier),
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, size: 20),
            label: const Text('Sync All'),
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
                    'Record your voice for each command. ${dog.name} will learn to respond to YOUR voice.',
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
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recording requires the iOS/Android app. Use mobile to record commands.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
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
                '$recorded of $total recorded',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '$synced synced',
                style: TextStyle(
                  color: synced == recorded && recorded > 0
                      ? Colors.green
                      : AppTheme.textSecondary,
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
              backgroundColor: AppTheme.surfaceLight,
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
          title: const Row(
            children: [
              Icon(Icons.phone_android),
              SizedBox(width: 8),
              Text('Mobile Required'),
            ],
          ),
          content: const Text(
            'Voice recording requires the iOS or Android app. '
            'Please use your mobile device to record voice commands.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // On mobile: show actual recording dialog
    final displayLabel = commandType == VoiceCommandType.name
        ? '"$dogName"'
        : commandType.label;

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
        title: const Text('Delete Recording?'),
        content: const Text('This will delete the recorded voice command.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        SnackBar(content: Text(success ? 'Command synced!' : 'Sync failed')),
      );
    }
  }

  Future<void> _syncAll(VoiceCommandsNotifier notifier) async {
    setState(() => _isSyncing = true);
    final count = await notifier.syncAll();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count commands synced to robot')),
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
        : commandType.label;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecorded
                ? (isSynced ? Colors.green : AppTheme.primary)
                : AppTheme.surfaceLight,
          ),
          child: Icon(
            isRecorded
                ? (isSynced ? Icons.cloud_done : Icons.check)
                : Icons.mic_none,
            color: isRecorded ? Colors.white : AppTheme.textTertiary,
            size: 20,
          ),
        ),
        title: Text(
          displayLabel,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isRecorded
              ? (isSynced ? 'Recorded & Synced' : 'Recorded - tap to sync')
              : 'Not recorded',
          style: TextStyle(
            fontSize: 12,
            color: isRecorded
                ? (isSynced ? Colors.green : AppTheme.primary)
                : AppTheme.textTertiary,
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
                  tooltip: 'Sync to robot',
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
            IconButton(
              icon: Icon(
                isRecorded ? Icons.refresh : Icons.mic,
                color: AppTheme.primary,
              ),
              onPressed: onRecord,
              tooltip: isRecorded ? 'Re-record' : 'Record',
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
        _error = 'Failed to start recording. Check microphone permission.';
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
        _error = 'Recording failed. Try again.';
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
      title: Text(_isDone ? 'Saved!' : 'Record: ${widget.commandLabel}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ] else if (_isDone) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text('Voice command recorded successfully!'),
          ] else if (_isRecording) ...[
            const Icon(Icons.mic, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              '${seconds}s',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Say the command clearly...'),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Preparing microphone...'),
          ],
        ],
      ),
      actions: [
        if (_error != null || _isDone)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isDone ? 'Done' : 'Close'),
          ),
        if (_error != null && !_isDone)
          TextButton(
            onPressed: () {
              setState(() => _error = null);
              _startRecording();
            },
            child: const Text('Retry'),
          ),
        if (_isRecording) ...[
          TextButton(
            onPressed: _cancelRecording,
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ],
    );
  }
}
