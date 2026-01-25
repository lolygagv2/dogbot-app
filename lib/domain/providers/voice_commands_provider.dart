import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

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

/// Check if we're on a mobile platform
bool get _isMobilePlatform {
  try {
    return Platform.isIOS || Platform.isAndroid;
  } catch (e) {
    return false;
  }
}

/// Voice commands notifier using record package
class VoiceCommandsNotifier extends StateNotifier<DogVoiceCommands> {
  final String dogId;
  final Ref _ref;
  SharedPreferences? _prefs;

  // Recording
  AudioRecorder? _recorder;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  VoiceCommandsNotifier(this.dogId, this._ref)
      : super(DogVoiceCommands(dogId: dogId)) {
    _loadCommands();
    print('VoiceCommands: Initialized for $dogId (isMobile=$_isMobilePlatform)');
  }

  @override
  void dispose() {
    _recorder?.dispose();
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

  /// Check if recording is available
  Future<bool> hasPermission() async {
    if (!_isMobilePlatform) return false;

    try {
      _recorder ??= AudioRecorder();
      return await _recorder!.hasPermission();
    } catch (e) {
      print('VoiceCommands: Permission check failed: $e');
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    if (!_isMobilePlatform) return false;

    try {
      _recorder ??= AudioRecorder();
      return await _recorder!.hasPermission();
    } catch (e) {
      print('VoiceCommands: Permission request failed: $e');
      return false;
    }
  }

  /// Start recording a voice command
  Future<bool> startRecording(String commandId) async {
    print('VoiceCommands: startRecording($commandId)');
    print('VoiceCommands: Platform.isIOS=${Platform.isIOS}, Platform.isAndroid=${Platform.isAndroid}');

    // Check platform directly for reliability
    final isMobile = Platform.isIOS || Platform.isAndroid;
    print('VoiceCommands: isMobile=$isMobile');

    if (!isMobile) {
      print('VoiceCommands: FAILED - Not on mobile platform');
      return false;
    }

    try {
      _recorder ??= AudioRecorder();

      final hasPermission = await _recorder!.hasPermission();
      print('VoiceCommands: hasPermission=$hasPermission');

      if (!hasPermission) {
        print('VoiceCommands: Permission denied');
        return false;
      }

      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_${dogId}_${commandId}_$timestamp.m4a';

      print('VoiceCommands: Recording to $_currentRecordingPath');

      // Start recording
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _recordingStartTime = DateTime.now();

      state = state.copyWith(
        isRecording: true,
        currentRecordingCommand: commandId,
      );
      _ref.read(isRecordingProvider.notifier).state = true;

      print('VoiceCommands: Recording started');
      return true;
    } catch (e) {
      print('VoiceCommands: Failed to start recording: $e');
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return false;
    }
  }

  /// Stop recording and save the voice command
  Future<VoiceCommand?> stopRecording() async {
    if (!state.isRecording || _recorder == null) return null;

    final commandId = state.currentRecordingCommand;
    if (commandId == null) {
      await cancelRecording();
      return null;
    }

    try {
      final path = await _recorder!.stop();
      print('VoiceCommands: Recording stopped, path=$path');

      if (path == null || path.isEmpty) {
        await cancelRecording();
        return null;
      }

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      final file = File(path);
      if (!await file.exists()) {
        print('VoiceCommands: File does not exist');
        await cancelRecording();
        return null;
      }

      final fileSize = await file.length();
      print('VoiceCommands: File size=$fileSize, duration=${durationMs}ms');

      // Move to permanent location
      final appDir = await getApplicationDocumentsDirectory();
      final permanentDir = '${appDir.path}/voice_commands';
      await Directory(permanentDir).create(recursive: true);

      final permanentPath = '$permanentDir/${dogId}_$commandId.m4a';

      // Delete existing
      final existingFile = File(permanentPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      // Copy and delete temp
      await file.copy(permanentPath);
      await file.delete();

      // Create command
      final command = VoiceCommand(
        dogId: dogId,
        commandId: commandId,
        localPath: permanentPath,
        recordedAt: DateTime.now(),
        isSynced: false,
        durationMs: durationMs,
      );

      // Update state
      final newCommands = Map<String, VoiceCommand>.from(state.commands);
      newCommands[commandId] = command;

      state = state.copyWith(
        commands: newCommands,
        isRecording: false,
        currentRecordingCommand: null,
      );
      _ref.read(isRecordingProvider.notifier).state = false;

      _currentRecordingPath = null;
      _recordingStartTime = null;

      await _saveCommands();

      print('VoiceCommands: Saved $commandId');
      return command;
    } catch (e) {
      print('VoiceCommands: Failed to stop recording: $e');
      await cancelRecording();
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (_recorder != null && state.isRecording) {
      try { await _recorder!.stop(); } catch (_) {}
    }

    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    state = state.copyWith(
      isRecording: false,
      currentRecordingCommand: null,
    );
    _ref.read(isRecordingProvider.notifier).state = false;

    _currentRecordingPath = null;
    _recordingStartTime = null;

    print('VoiceCommands: Recording cancelled');
  }

  /// Delete a recorded command
  Future<void> deleteCommand(String commandId) async {
    final command = state.commands[commandId];
    if (command?.localPath != null) {
      try {
        final file = File(command!.localPath!);
        if (await file.exists()) await file.delete();
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

      WebSocketClient.instance.sendVoiceCommand(commandId, base64Data);

      final updatedCommand = command.copyWith(
        isSynced: true,
        syncedAt: DateTime.now(),
      );

      final newCommands = Map<String, VoiceCommand>.from(state.commands);
      newCommands[commandId] = updatedCommand;
      state = state.copyWith(commands: newCommands);

      await _saveCommands();
      print('VoiceCommands: Synced $commandId');
      return true;
    } catch (e) {
      print('VoiceCommands: Failed to sync $commandId: $e');
      return false;
    }
  }

  /// Sync all recorded commands
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

  bool isCommandRecorded(String commandId) {
    return state.commands[commandId]?.localPath != null;
  }

  bool isCommandSynced(String commandId) {
    return state.commands[commandId]?.isSynced ?? false;
  }

  int get recordedCount {
    return state.commands.values.where((c) => c.localPath != null).length;
  }

  int get syncedCount {
    return state.commands.values.where((c) => c.isSynced).length;
  }
}
