import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Voice commands notifier - STUBBED (flutter_sound disabled for debugging)
class VoiceCommandsNotifier extends StateNotifier<DogVoiceCommands> {
  final String dogId;
  final Ref _ref;
  SharedPreferences? _prefs;

  VoiceCommandsNotifier(this.dogId, this._ref)
      : super(DogVoiceCommands(dogId: dogId)) {
    _loadCommands();
    print('VoiceCommands: Initialized for $dogId (recording DISABLED for debugging)');
  }

  @override
  void dispose() {
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

  /// Check if recording is available - DISABLED
  Future<bool> hasPermission() async {
    return false;
  }

  /// Request microphone permission - DISABLED
  Future<bool> requestPermission() async {
    return false;
  }

  /// Start recording a voice command - DISABLED
  Future<bool> startRecording(String commandId) async {
    print('VoiceCommands: Recording DISABLED for debugging white screen');
    return false;
  }

  /// Stop recording and save the voice command - DISABLED
  Future<VoiceCommand?> stopRecording() async {
    return null;
  }

  /// Cancel recording without saving - DISABLED
  Future<void> cancelRecording() async {
    state = state.copyWith(
      isRecording: false,
      currentRecordingCommand: null,
    );
    _ref.read(isRecordingProvider.notifier).state = false;
    print('VoiceCommands: Recording cancelled');
  }

  /// Delete a recorded command
  Future<void> deleteCommand(String commandId) async {
    final newCommands = Map<String, VoiceCommand>.from(state.commands);
    newCommands.remove(commandId);
    state = state.copyWith(commands: newCommands);
    await _saveCommands();
  }

  /// Sync a command to the robot
  Future<bool> syncCommand(String commandId) async {
    final command = state.commands[commandId];
    if (command?.localPath == null) return false;

    // Just mark as synced for now
    final updatedCommand = command!.copyWith(
      isSynced: true,
      syncedAt: DateTime.now(),
    );

    final newCommands = Map<String, VoiceCommand>.from(state.commands);
    newCommands[commandId] = updatedCommand;
    state = state.copyWith(commands: newCommands);

    await _saveCommands();
    print('VoiceCommands: Marked $commandId as synced');
    return true;
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
