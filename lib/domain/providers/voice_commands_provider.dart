import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

/// Check if we're on a mobile platform (uses print, not rprint, for safe early init)
bool get _isMobilePlatform {
  try {
    final isIOS = Platform.isIOS;
    final isAndroid = Platform.isAndroid;
    // Use print() not rprint() - this runs during early init before WebSocket is ready
    print('VoiceCommands: Platform check - isIOS=$isIOS, isAndroid=$isAndroid');
    return isIOS || isAndroid;
  } catch (e) {
    print('VoiceCommands: Platform check failed (web?): $e');
    return false; // Web platform
  }
}

/// Voice commands notifier - Full implementation for mobile, stubbed for desktop
class VoiceCommandsNotifier extends StateNotifier<DogVoiceCommands> {
  final String dogId;
  final Ref _ref;
  SharedPreferences? _prefs;

  // Recording
  FlutterSoundRecorder? _recorder;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isRecorderInitialized = false;

  VoiceCommandsNotifier(this.dogId, this._ref)
      : super(DogVoiceCommands(dogId: dogId)) {
    _loadCommands();
    // Don't initialize recorder in constructor - do it lazily when needed
    // This prevents crashes during app startup
  }

  Future<void> _initRecorder() async {
    print('VoiceCommands: _initRecorder() called');

    try {
      _recorder = FlutterSoundRecorder();
      print('VoiceCommands: FlutterSoundRecorder created');
    } catch (e) {
      print('VoiceCommands: FAILED to create FlutterSoundRecorder: $e');
      _isRecorderInitialized = false;
      return;
    }

    try {
      await _recorder!.openRecorder();
      _isRecorderInitialized = true;
      print('VoiceCommands: Recorder initialized');
    } catch (e) {
      print('VoiceCommands: Failed to openRecorder: $e');
      _isRecorderInitialized = false;
    }
  }

  @override
  void dispose() {
    if (_recorder != null && _isRecorderInitialized) {
      _recorder!.closeRecorder();
    }
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
        rprint('VoiceCommands: Loaded ${commands.length} commands for $dogId');
      } catch (e) {
        rprint('VoiceCommands: Failed to load commands: $e');
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
    rprint('VoiceCommands: Saved ${state.commands.length} commands');
  }

  /// Check if recording is available
  Future<bool> hasPermission() async {
    if (!_isMobilePlatform) {
      rprint('VoiceCommands: Recording only available on mobile platforms');
      return false;
    }

    final status = await Permission.microphone.status;
    rprint('VoiceCommands: Microphone permission status: $status');
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    if (!_isMobilePlatform) {
      return false;
    }

    rprint('VoiceCommands: Requesting microphone permission...');
    final status = await Permission.microphone.request();
    rprint('VoiceCommands: Permission result: $status');

    if (status.isPermanentlyDenied) {
      rprint('VoiceCommands: Permission permanently denied - user must enable in settings');
      return false;
    }

    return status.isGranted;
  }

  /// Start recording a voice command
  Future<bool> startRecording(String commandId) async {
    rprint('VoiceCommands: startRecording called for $commandId');

    // Platform check
    final isMobile = _isMobilePlatform;
    rprint('VoiceCommands: isMobilePlatform = $isMobile');
    if (!isMobile) {
      rprint('VoiceCommands: Recording only available on mobile (iOS/Android)');
      return false;
    }

    // Permission check
    rprint('VoiceCommands: Checking permission...');
    final hasPerm = await hasPermission();
    rprint('VoiceCommands: hasPermission = $hasPerm');
    if (!hasPerm) {
      rprint('VoiceCommands: Requesting permission...');
      final granted = await requestPermission();
      rprint('VoiceCommands: Permission granted = $granted');
      if (!granted) {
        rprint('VoiceCommands: Microphone permission denied');
        return false;
      }
    }

    // Ensure recorder is initialized
    rprint('VoiceCommands: Checking recorder - recorder=$_recorder, initialized=$_isRecorderInitialized');
    if (_recorder == null || !_isRecorderInitialized) {
      rprint('VoiceCommands: Initializing recorder...');
      await _initRecorder();
      rprint('VoiceCommands: After init - initialized=$_isRecorderInitialized');
      if (!_isRecorderInitialized) {
        rprint('VoiceCommands: Recorder not available after init');
        return false;
      }
    }

    try {
      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_${dogId}_${commandId}_$timestamp.aac';

      // Start recording - AAC format, 16kHz sample rate, mono channel
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
        sampleRate: 16000,
        numChannels: 1,
      );

      _recordingStartTime = DateTime.now();

      state = state.copyWith(
        isRecording: true,
        currentRecordingCommand: commandId,
      );
      _ref.read(isRecordingProvider.notifier).state = true;

      rprint('VoiceCommands: Started recording for $commandId at $_currentRecordingPath');
      return true;
    } catch (e) {
      rprint('VoiceCommands: Failed to start recording: $e');
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return false;
    }
  }

  /// Stop recording and save the voice command
  Future<VoiceCommand?> stopRecording() async {
    if (!state.isRecording || _recorder == null) {
      return null;
    }

    final commandId = state.currentRecordingCommand;
    if (commandId == null) {
      await cancelRecording();
      return null;
    }

    try {
      // Stop recording
      final path = await _recorder!.stopRecorder();

      if (path == null || path.isEmpty) {
        rprint('VoiceCommands: Recording returned null path');
        await cancelRecording();
        return null;
      }

      // Calculate duration
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      // Verify file exists
      final file = File(path);
      if (!await file.exists()) {
        rprint('VoiceCommands: Recording file does not exist at $path');
        await cancelRecording();
        return null;
      }

      final fileSize = await file.length();
      rprint('VoiceCommands: Recording saved: $path ($fileSize bytes, ${durationMs}ms)');

      // Move to permanent location
      final appDir = await getApplicationDocumentsDirectory();
      final permanentDir = '${appDir.path}/voice_commands';
      await Directory(permanentDir).create(recursive: true);

      final permanentPath = '$permanentDir/${dogId}_$commandId.aac';

      // Delete existing file if present
      final existingFile = File(permanentPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      // Move file
      await file.copy(permanentPath);
      await file.delete();

      // Create voice command
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

      // Save to persistent storage
      await _saveCommands();

      rprint('VoiceCommands: Successfully recorded $commandId');
      return command;
    } catch (e) {
      rprint('VoiceCommands: Failed to stop recording: $e');
      await cancelRecording();
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (_recorder != null && state.isRecording) {
      try {
        await _recorder!.stopRecorder();
      } catch (e) {
        rprint('VoiceCommands: Error stopping recorder: $e');
      }
    }

    // Clean up temp file if exists
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        rprint('VoiceCommands: Error deleting temp file: $e');
      }
    }

    state = state.copyWith(
      isRecording: false,
      currentRecordingCommand: null,
    );
    _ref.read(isRecordingProvider.notifier).state = false;

    _currentRecordingPath = null;
    _recordingStartTime = null;

    rprint('VoiceCommands: Recording cancelled');
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
        rprint('VoiceCommands: Failed to delete file: $e');
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
      rprint('VoiceCommands: Synced $commandId to robot');
      return true;
    } catch (e) {
      rprint('VoiceCommands: Failed to sync $commandId: $e');
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
