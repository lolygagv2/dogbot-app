import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../../../data/models/dog_profile.dart';
import '../../../data/models/voice_command.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/voice_commands_provider.dart';
import '../../theme/app_theme.dart';

/// Voice command recording setup screen
class VoiceSetupScreen extends ConsumerStatefulWidget {
  final String? dogId;

  const VoiceSetupScreen({super.key, this.dogId});

  @override
  ConsumerState<VoiceSetupScreen> createState() => _VoiceSetupScreenState();
}

class _VoiceSetupScreenState extends ConsumerState<VoiceSetupScreen> {
  FlutterSoundPlayer? _audioPlayer;
  String? _playingCommand;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (Platform.isLinux) return;
    _audioPlayer = FlutterSoundPlayer();
    await _audioPlayer!.openPlayer();
  }

  DogProfile? get _dog {
    if (widget.dogId != null) {
      return ref.watch(dogProfileProvider(widget.dogId!));
    }
    return ref.watch(selectedDogProvider);
  }

  @override
  void dispose() {
    _audioPlayer?.closePlayer();
    super.dispose();
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
                final isRecording = voiceCommands.isRecording &&
                    voiceCommands.currentRecordingCommand == commandType.id;
                final isPlaying = _playingCommand == commandType.id;

                return _CommandTile(
                  commandType: commandType,
                  command: command,
                  dogName: dog.name,
                  isRecording: isRecording,
                  isPlaying: isPlaying,
                  onRecord: () => _showRecordDialog(context, commandType, dog.name, notifier),
                  onPlay: command?.localPath != null
                      ? () => _playCommand(command!.localPath!)
                      : null,
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

  Future<void> _showRecordDialog(
    BuildContext context,
    VoiceCommandType commandType,
    String dogName,
    VoiceCommandsNotifier notifier,
  ) async {
    // Get the prompt text (replace "Dog's Name" with actual name)
    String promptText = commandType == VoiceCommandType.name
        ? dogName
        : commandType.label;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordDialog(
        commandType: commandType,
        promptText: promptText,
        notifier: notifier,
        onComplete: (success) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${commandType.label} recorded!')),
            );
          }
        },
      ),
    );
  }

  Future<void> _playCommand(String path) async {
    if (Platform.isLinux || _audioPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback not supported on desktop')),
      );
      return;
    }

    try {
      if (_playingCommand != null) {
        await _audioPlayer!.stopPlayer();
      }

      setState(() => _playingCommand = path);

      await _audioPlayer!.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) {
            setState(() => _playingCommand = null);
          }
        },
      );
    } catch (e) {
      setState(() => _playingCommand = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
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
        SnackBar(
          content: Text(success ? 'Command synced!' : 'Sync failed'),
        ),
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
  final bool isRecording;
  final bool isPlaying;
  final VoidCallback onRecord;
  final VoidCallback? onPlay;
  final VoidCallback? onDelete;
  final VoidCallback? onSync;

  const _CommandTile({
    required this.commandType,
    this.command,
    required this.dogName,
    required this.isRecording,
    required this.isPlaying,
    required this.onRecord,
    this.onPlay,
    this.onDelete,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final isRecorded = command?.localPath != null;
    final isSynced = command?.isSynced ?? false;

    // Get display label (replace "Dog's Name" with actual name)
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
              // Play button
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  color: AppTheme.primary,
                ),
                onPressed: onPlay,
                tooltip: isPlaying ? 'Stop' : 'Play',
              ),
              // Sync button
              if (!isSynced)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  onPressed: onSync,
                  tooltip: 'Sync to robot',
                ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
            // Record button
            IconButton(
              icon: Icon(
                isRecorded ? Icons.refresh : Icons.mic,
                color: isRecording ? Colors.red : AppTheme.primary,
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

/// Recording dialog with hold-to-record UI
class _RecordDialog extends ConsumerStatefulWidget {
  final VoiceCommandType commandType;
  final String promptText;
  final VoiceCommandsNotifier notifier;
  final void Function(bool success) onComplete;

  const _RecordDialog({
    required this.commandType,
    required this.promptText,
    required this.notifier,
    required this.onComplete,
  });

  @override
  ConsumerState<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends ConsumerState<_RecordDialog> {
  bool _isRecording = false;
  bool _hasRecorded = false;
  double _recordingProgress = 0;
  Timer? _progressTimer;
  Timer? _maxDurationTimer;
  VoiceCommand? _recordedCommand;
  FlutterSoundPlayer? _previewPlayer;
  bool _isPlaying = false;

  static const _maxDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (Platform.isLinux) return;
    _previewPlayer = FlutterSoundPlayer();
    await _previewPlayer!.openPlayer();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _maxDurationTimer?.cancel();
    _previewPlayer?.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.mic),
          const SizedBox(width: 8),
          Text(widget.commandType.label),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt
          Text(
            'Say: "${widget.promptText}"',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.commandType.prompt,
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Recording button
          GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            onTapCancel: () => _stopRecording(),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : AppTheme.primary,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: Colors.red.withAlpha(128),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring
                  if (_isRecording)
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: _recordingProgress,
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  // Mic icon
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 40,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording
                ? 'Recording... (release to stop)'
                : (_hasRecorded ? 'Tap and hold to re-record' : 'Hold to record'),
            style: TextStyle(
              color: _isRecording ? Colors.red : AppTheme.textSecondary,
              fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          // Preview section
          if (_hasRecorded && _recordedCommand != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _playPreview,
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isPlaying ? 'Stop' : 'Preview'),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.notifier.cancelRecording();
            Navigator.pop(context);
            widget.onComplete(false);
          },
          child: const Text('Cancel'),
        ),
        if (_hasRecorded)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(true);
            },
            child: const Text('Save'),
          ),
      ],
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final started = await widget.notifier.startRecording(widget.commandType.id);
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start recording. Check microphone permission.')),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingProgress = 0;
    });

    // Progress timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _recordingProgress += 0.05 / _maxDuration.inSeconds;
        if (_recordingProgress > 1) _recordingProgress = 1;
      });
    });

    // Max duration timer
    _maxDurationTimer = Timer(_maxDuration, () {
      _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _progressTimer?.cancel();
    _maxDurationTimer?.cancel();

    final command = await widget.notifier.stopRecording();

    setState(() {
      _isRecording = false;
      _hasRecorded = command != null;
      _recordedCommand = command;
    });
  }

  Future<void> _playPreview() async {
    if (_recordedCommand?.localPath == null) return;

    if (Platform.isLinux || _previewPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback not supported on desktop')),
      );
      return;
    }

    if (_isPlaying) {
      await _previewPlayer!.stopPlayer();
      setState(() => _isPlaying = false);
      return;
    }

    try {
      setState(() => _isPlaying = true);
      await _previewPlayer!.startPlayer(
        fromURI: _recordedCommand!.localPath!,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        },
      );
    } catch (e) {
      setState(() => _isPlaying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
  }
}
