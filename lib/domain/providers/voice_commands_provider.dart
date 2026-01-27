import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/voice_command.dart';
import '../../core/network/websocket_client.dart';
import '../../core/utils/remote_logger.dart';

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
    rlog('VOICE', 'startRecording($commandId)');
    rlog('VOICE', 'Platform.isIOS=${Platform.isIOS}, Platform.isAndroid=${Platform.isAndroid}');

    final isMobile = Platform.isIOS || Platform.isAndroid;
    if (!isMobile) {
      rlog('VOICE', 'FAILED - Not on mobile platform');
      return false;
    }

    try {
      // Create fresh recorder to avoid stale state
      rlog('VOICE', 'Creating fresh AudioRecorder...');
      _recorder?.dispose();
      _recorder = AudioRecorder();

      final hasPermission = await _recorder!.hasPermission();
      rlog('VOICE', 'hasPermission=$hasPermission');

      if (!hasPermission) {
        rlog('VOICE', 'FAILED - Permission denied');
        return false;
      }

      // Use WAV format - raw PCM always works on iOS
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_${dogId}_${commandId}_$timestamp.wav';

      rlog('VOICE', 'Recording to $_currentRecordingPath');

      rlog('VOICE', 'Starting recorder (WAV, 44100Hz, mono)...');
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
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

      rlog('VOICE', 'Recording started successfully');
      return true;
    } catch (e) {
      rlog('VOICE', 'ERROR starting recording: $e');
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
      rlog('VOICE', 'Stopping recorder...');
      final path = await _recorder!.stop();
      rlog('VOICE', 'Recorder stopped, path=$path');

      if (path == null || path.isEmpty) {
        rlog('VOICE', 'ERROR: Empty path returned');
        await cancelRecording();
        return null;
      }

      // Wait for filesystem to flush
      await Future.delayed(const Duration(milliseconds: 500));

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      final file = File(path);
      if (!await file.exists()) {
        rlog('VOICE', 'ERROR: File does not exist at $path');
        await cancelRecording();
        return null;
      }

      final fileSize = await file.length();
      rlog('VOICE', 'File size=$fileSize bytes, duration=${durationMs}ms');

      // Check for empty recording
      if (fileSize < 1000) {
        rlog('VOICE', 'ERROR: File too small ($fileSize bytes) - recording is empty');
        try { await file.delete(); } catch (_) {}
        await cancelRecording();
        return null;
      }

      // Move to permanent location (use .wav extension)
      final appDir = await getApplicationDocumentsDirectory();
      final permanentDir = '${appDir.path}/voice_commands';
      await Directory(permanentDir).create(recursive: true);

      final permanentPath = '$permanentDir/${dogId}_$commandId.wav';

      final existingFile = File(permanentPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      await file.copy(permanentPath);
      await file.delete();

      final command = VoiceCommand(
        dogId: dogId,
        commandId: commandId,
        localPath: permanentPath,
        recordedAt: DateTime.now(),
        isSynced: false,
        durationMs: durationMs,
      );

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

      rlog('VOICE', 'Saved $commandId ($fileSize bytes)');
      return command;
    } catch (e) {
      rlog('VOICE', 'ERROR stopping recording: $e');
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

      rlog('VOICE', 'Syncing $commandId for dog $dogId: ${bytes.length} bytes raw, format=wav');
      WebSocketClient.instance.sendVoiceCommand(commandId, base64Data, dogId: dogId);

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
