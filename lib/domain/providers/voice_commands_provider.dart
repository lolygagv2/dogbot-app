import 'dart:convert';
import 'dart:io' show File, Directory, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/voice_command.dart';
import '../../core/network/websocket_client.dart';

const String _voiceCommandsKey = 'voice_commands';

/// Provider for voice commands state per dog
final voiceCommandsProvider = StateNotifierProvider.family<
    VoiceCommandsNotifier, DogVoiceCommands, String>((ref, dogId) {
  return VoiceCommandsNotifier(dogId, ref);
});

/// Provider for recording state
final isRecordingProvider = StateProvider<bool>((ref) => false);

/// Provider for current playback command
final playingCommandProvider = StateProvider<String?>((ref) => null);

/// Voice commands notifier with persistence and recording
class VoiceCommandsNotifier extends StateNotifier<DogVoiceCommands> {
  final String dogId;
  final Ref _ref;
  SharedPreferences? _prefs;
  final AudioRecorder _recorder = AudioRecorder();

  VoiceCommandsNotifier(this.dogId, this._ref)
      : super(DogVoiceCommands(dogId: dogId)) {
    _loadCommands();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadCommands() async {
    _prefs = await SharedPreferences.getInstance();
    final json = _prefs?.getString('${_voiceCommandsKey}_$dogId');

    if (json != null && json.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(json);
        final commands = <String, VoiceCommand>{};

        for (final entry in data.entries) {
          commands[entry.key] =
              VoiceCommand.fromJson(entry.value as Map<String, dynamic>);
        }

        state = state.copyWith(commands: commands);
        print('VoiceCommands: Loaded ${commands.length} commands for $dogId');
      } catch (e) {
        print('VoiceCommands: Failed to load commands: $e');
      }
    }
  }

  Future<void> _saveCommands() async {
    _prefs ??= await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    for (final entry in state.commands.entries) {
      data[entry.key] = entry.value.toJson();
    }

    await _prefs?.setString('${_voiceCommandsKey}_$dogId', jsonEncode(data));
    print('VoiceCommands: Saved ${state.commands.length} commands');
  }

  /// Get the file path for a command recording
  Future<String> _getRecordingPath(String commandId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${appDir.path}/voice_commands');
    if (!voiceDir.existsSync()) {
      voiceDir.createSync(recursive: true);
    }
    return '${voiceDir.path}/${dogId}_$commandId.m4a';
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording a command
  Future<bool> startRecording(String commandId) async {
    if (Platform.isLinux) {
      print('VoiceCommands: Recording not supported on Linux');
      return false;
    }

    if (!await hasPermission()) {
      print('VoiceCommands: No microphone permission');
      return false;
    }

    if (state.isRecording) {
      await stopRecording();
    }

    try {
      final path = await _getRecordingPath(commandId);

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      state = state.copyWith(
        isRecording: true,
        currentRecordingCommand: commandId,
      );
      _ref.read(isRecordingProvider.notifier).state = true;

      print('VoiceCommands: Started recording $commandId');
      return true;
    } catch (e) {
      print('VoiceCommands: Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and save the command
  Future<VoiceCommand?> stopRecording() async {
    if (!state.isRecording || state.currentRecordingCommand == null) {
      return null;
    }

    try {
      final path = await _recorder.stop();
      final commandId = state.currentRecordingCommand!;

      state = state.copyWith(
        isRecording: false,
        currentRecordingCommand: null,
      );
      _ref.read(isRecordingProvider.notifier).state = false;

      if (path == null) {
        print('VoiceCommands: Recording returned null path');
        return null;
      }

      // Get file info for duration estimation
      final file = File(path);
      final fileSize = await file.length();
      // Rough estimate: ~16KB per second at 128kbps
      final estimatedDurationMs = (fileSize / 16000 * 1000).toInt();

      final command = VoiceCommand(
        dogId: dogId,
        commandId: commandId,
        localPath: path,
        recordedAt: DateTime.now(),
        isSynced: false,
        durationMs: estimatedDurationMs,
      );

      // Update state
      final newCommands = Map<String, VoiceCommand>.from(state.commands);
      newCommands[commandId] = command;
      state = state.copyWith(commands: newCommands);

      await _saveCommands();
      print('VoiceCommands: Saved recording $commandId at $path');

      return command;
    } catch (e) {
      print('VoiceCommands: Failed to stop recording: $e');
      state = state.copyWith(
        isRecording: false,
        currentRecordingCommand: null,
      );
      _ref.read(isRecordingProvider.notifier).state = false;
      return null;
    }
  }

  /// Cancel current recording without saving
  Future<void> cancelRecording() async {
    if (state.isRecording) {
      await _recorder.stop();
      state = state.copyWith(
        isRecording: false,
        currentRecordingCommand: null,
      );
      _ref.read(isRecordingProvider.notifier).state = false;
    }
  }

  /// Delete a recorded command
  Future<void> deleteCommand(String commandId) async {
    final command = state.commands[commandId];
    if (command?.localPath != null) {
      try {
        final file = File(command!.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('VoiceCommands: Failed to delete file: $e');
      }
    }

    final newCommands = Map<String, VoiceCommand>.from(state.commands);
    newCommands.remove(commandId);
    state = state.copyWith(commands: newCommands);

    await _saveCommands();
  }

  /// Sync a command to the robot
  Future<bool> syncCommand(String commandId) async {
    final command = state.commands[commandId];
    if (command?.localPath == null) return false;

    try {
      final file = File(command!.localPath!);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Send via WebSocket
      WebSocketClient.instance.sendVoiceCommand(commandId, base64Data);

      // Update sync status
      final updatedCommand = command.copyWith(
        isSynced: true,
        syncedAt: DateTime.now(),
      );

      final newCommands = Map<String, VoiceCommand>.from(state.commands);
      newCommands[commandId] = updatedCommand;
      state = state.copyWith(commands: newCommands);

      await _saveCommands();
      print('VoiceCommands: Synced $commandId to robot');
      return true;
    } catch (e) {
      print('VoiceCommands: Failed to sync $commandId: $e');
      return false;
    }
  }

  /// Sync all recorded commands to the robot
  Future<int> syncAll() async {
    int syncedCount = 0;

    for (final commandId in state.commands.keys) {
      final command = state.commands[commandId];
      if (command?.localPath != null && !(command?.isSynced ?? true)) {
        if (await syncCommand(commandId)) {
          syncedCount++;
        }
      }
    }

    return syncedCount;
  }

  /// Get recording progress as a fraction (0-1)
  bool isCommandRecorded(String commandId) {
    return state.commands[commandId]?.localPath != null;
  }

  /// Get sync status for a command
  bool isCommandSynced(String commandId) {
    return state.commands[commandId]?.isSynced ?? false;
  }

  /// Get the number of recorded commands
  int get recordedCount {
    return state.commands.values
        .where((c) => c.localPath != null)
        .length;
  }

  /// Get the number of synced commands
  int get syncedCount {
    return state.commands.values.where((c) => c.isSynced).length;
  }
}
