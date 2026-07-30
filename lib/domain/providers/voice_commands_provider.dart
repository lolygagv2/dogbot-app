import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/robot_api.dart';
import '../../data/models/voice_command.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../core/utils/remote_logger.dart';
import '../../core/utils/time_utils.dart';
import 'auth_provider.dart';
import 'dog_profiles_provider.dart';

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

  /// Test seam: seed a command without going through the recorder.
  @visibleForTesting
  void debugSetCommand(VoiceCommand command) {
    final newCommands = Map<String, VoiceCommand>.from(state.commands);
    newCommands[command.commandId] = command;
    state = state.copyWith(commands: newCommands);
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

      // Recording alone never reaches the robot — push it now instead of
      // relying on a manual sync tap. On failure the command stays unsynced
      // and the reconnect auto-sync retries it.
      unawaited(syncCommand(commandId));

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

    // A2: also remove from relay so other devices stop seeing it.
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (!isLocal && token != null) {
      try {
        final api = _ref.read(robotApiProvider);
        await api.deleteVoiceCommand(
          token: token,
          dogId: dogId,
          commandId: commandId,
        );
      } catch (e) {
        print('VoiceCommands: Failed to delete on relay: $e');
      }
    }

    final newCommands = Map<String, VoiceCommand>.from(state.commands);
    newCommands.remove(commandId);
    state = state.copyWith(commands: newCommands);

    await _saveCommands();
  }

  /// Sync a command to the robot.
  ///
  /// A2: Cloud-mode path — upload WAV to the relay; relay pushes
  /// `voice_command_updated` to the robot which downloads from relay.
  /// Local-mode path — send the WAV directly via WS `upload_voice` (the
  /// robot's native local-AP contract).
  ///
  /// A cloud upload failure leaves the command UNSYNCED — no WS fallback, no
  /// blind isSynced=true. The unsynced flag is the retry signal: the tile
  /// keeps its "tap to sync" state and the reconnect auto-sync re-pushes it.
  Future<bool> syncCommand(String commandId) async {
    final command = state.commands[commandId];
    if (command?.localPath == null) return false;

    try {
      final file = File(command!.localPath!);
      if (!await file.exists()) return false;

      final isLocal = _ref.read(localConnectionProvider).isConnected;

      if (isLocal) {
        // Local-mode — send WAV bytes via WS. Fire-and-forget by contract:
        // the robot has no upload ack, so synced is marked optimistically
        // (unchanged pre-Build-87 behavior).
        final bytes = await file.readAsBytes();
        final base64Data = base64Encode(bytes);
        rlog('VOICE',
            'Syncing $commandId via WS for dog $dogId: ${bytes.length} bytes');
        WebSocketClient.instance
            .sendVoiceCommand(commandId, base64Data, dogId: dogId);
        await _storeSynced(commandId, command.copyWith(
          isSynced: true,
          syncedAt: DateTime.now(),
        ));
        return true;
      }

      final token = _ref.read(authProvider).token;
      if (token == null) {
        rlog('VOICE', 'Sync $commandId skipped: cloud mode without auth token');
        return false;
      }

      // Cloud path — relay-mediated.
      final api = _ref.read(robotApiProvider);
      final result = await api.uploadVoiceCommand(
        token: token,
        dogId: dogId,
        commandId: commandId,
        filePath: command.localPath!,
      );
      if (result == null) {
        rlog('VOICE', 'Relay upload failed for $commandId — left unsynced for retry');
        return false;
      }

      final relayUrl = result['audio_url'] as String?;
      final relayUpdatedAt =
          tryParseServerTimestamp(result['updated_at'] as String?);
      await _storeSynced(commandId, command.copyWith(
        isSynced: true,
        syncedAt: DateTime.now(),
        relayUrl: relayUrl,
        relayUpdatedAt: relayUpdatedAt,
      ));
      rlog('VOICE', 'Synced $commandId via relay (url=$relayUrl)');
      return true;
    } catch (e) {
      rlog('VOICE', 'Failed to sync $commandId: $e');
      return false;
    }
  }

  Future<void> _storeSynced(String commandId, VoiceCommand updated) async {
    final newCommands = Map<String, VoiceCommand>.from(state.commands);
    newCommands[commandId] = updated;
    state = state.copyWith(commands: newCommands);
    await _saveCommands();
  }

  /// Delete every recording for this dog so the robot falls back to its
  /// default voice. deleteCommand already propagates each removal to the
  /// relay, which pushes voice_command_deleted to the robot.
  Future<int> resetAllToDefault() async {
    final ids = state.commands.keys.toList();
    for (final id in ids) {
      await deleteCommand(id);
    }
    rlog('VOICE', 'Reset to default: deleted ${ids.length} commands for dog $dogId');
    return ids.length;
  }

  /// A2: Hydrate voice command audio for this dog from the relay.
  /// On a fresh install the manifest gives us {command_id, audio_url,
  /// updated_at, ...}; we download any WAVs we don't already have locally
  /// and persist them to `voice_commands/{dogId}_{commandId}.wav`.
  Future<void> hydrateFromRelay() async {
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (isLocal || token == null) return;

    try {
      final api = _ref.read(robotApiProvider);
      final manifest = await api.getVoiceCommands(token: token, dogId: dogId);
      if (manifest.isEmpty) {
        print('VoiceCommands[$dogId]: relay manifest empty');
        return;
      }
      print('VoiceCommands[$dogId]: hydrating ${manifest.length} from relay');

      final appDir = await getApplicationDocumentsDirectory();
      final permanentDir = '${appDir.path}/voice_commands';
      await Directory(permanentDir).create(recursive: true);

      final newCommands = Map<String, VoiceCommand>.from(state.commands);

      for (final entry in manifest) {
        final commandId = entry['command_id'] as String?;
        final audioUrl = entry['audio_url'] as String?;
        final updatedAtStr = entry['updated_at'] as String?;
        if (commandId == null || audioUrl == null) continue;
        // Guard against relay filter drift: a manifest entry stamped with a
        // different dog's id must never be adopted for this dog — that's how
        // a freshly-added dog "inherited" another dog's recordings.
        final entryDogId = entry['dog_id'] as String?;
        if (entryDogId != null && entryDogId != dogId) {
          rlog('VOICE',
              'hydrate[$dogId]: dropped $commandId stamped for dog $entryDogId');
          continue;
        }
        final updatedAt = tryParseServerTimestamp(updatedAtStr);

        final existing = newCommands[commandId];
        final existingFile = existing?.localPath != null
            ? File(existing!.localPath!)
            : null;
        final localExists =
            existingFile != null && await existingFile.exists();
        final localStale = existing?.relayUpdatedAt == null ||
            (updatedAt != null && updatedAt.isAfter(existing!.relayUpdatedAt!));

        if (localExists && !localStale) {
          // Already up to date — just record the relay URL.
          newCommands[commandId] = existing!.copyWith(
            relayUrl: audioUrl,
            relayUpdatedAt: updatedAt,
          );
          continue;
        }

        // Download the WAV.
        final bytes = await api.downloadVoiceCommand(audioUrl);
        if (bytes == null) {
          // Relay row exists but the file is gone (pre-2026-07-30 /tmp
          // storage was wiped on reboot). If we still hold a local copy,
          // flip it unsynced so auto-sync re-uploads and heals the relay.
          if (localExists) {
            newCommands[commandId] = existing!.copyWith(isSynced: false);
            rlog('VOICE',
                'hydrate[$dogId]: $commandId gone on relay — marked for re-sync');
          } else {
            rlog('VOICE', 'hydrate[$dogId]: download failed for $commandId');
          }
          continue;
        }
        final permanentPath = '$permanentDir/${dogId}_$commandId.wav';
        final file = File(permanentPath);
        if (await file.exists()) await file.delete();
        await file.writeAsBytes(bytes);

        newCommands[commandId] = VoiceCommand(
          dogId: dogId,
          commandId: commandId,
          localPath: permanentPath,
          recordedAt: existing?.recordedAt ?? updatedAt ?? DateTime.now(),
          isSynced: true,
          syncedAt: DateTime.now(),
          durationMs: existing?.durationMs ?? 0,
          relayUrl: audioUrl,
          relayUpdatedAt: updatedAt,
        );
        print('VoiceCommands[$dogId]: downloaded $commandId (${bytes.length} bytes)');
      }

      state = state.copyWith(commands: newCommands);
      await _saveCommands();
    } catch (e) {
      print('VoiceCommands[$dogId]: hydrateFromRelay error: $e');
    }
  }

  /// Sync all recorded commands.
  ///
  /// [force] re-uploads even commands already marked synced — the manual
  /// "Sync All" heal for relay-side file loss (pre-2026-07-30 /tmp storage).
  /// The reconnect auto-sync keeps force=false so it only pushes pending ones.
  Future<int> syncAll({bool force = false}) async {
    int syncedCount = 0;

    for (final commandId in state.commands.keys.toList()) {
      final command = state.commands[commandId];
      if (command?.localPath == null) continue;
      if (!force && (command?.isSynced ?? true)) continue;
      if (await syncCommand(commandId)) {
        syncedCount++;
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

/// Build 104 — voice commands auto-sync coordinator.
///
/// Background: users were recording voice commands while the robot was
/// offline (or while WS was disconnected) and then losing them — the only
/// path to actually deliver them was the user manually tapping "Sync All"
/// while connected. This provider closes that loop: whenever the WS
/// transitions into `connected`, every dog's notifier is told to syncAll(),
/// which re-pushes any commands flagged `isSynced=false`. Commands already
/// confirmed synced are skipped.
///
/// Instantiated once at app startup via `ref.read(voiceCommandsAutoSyncProvider)`
/// in app.dart so the subscription exists for the life of the process.
final voiceCommandsAutoSyncProvider = Provider<VoiceCommandsAutoSync>((ref) {
  final coordinator = VoiceCommandsAutoSync(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class VoiceCommandsAutoSync {
  final Ref _ref;
  StreamSubscription<WsConnectionState>? _wsSub;
  WsConnectionState _last = WsConnectionState.disconnected;

  VoiceCommandsAutoSync(this._ref) {
    final ws = _ref.read(websocketClientProvider);
    _last = ws.state;
    _wsSub = ws.stateStream.listen((next) {
      if (next == WsConnectionState.connected &&
          _last != WsConnectionState.connected) {
        // Fire-and-forget: don't block the WS event loop on uploads.
        // ignore: discarded_futures
        _pushAllPending();
      }
      _last = next;
    });
  }

  Future<void> _pushAllPending() async {
    try {
      final dogs = _ref.read(dogProfilesProvider);
      var totalPending = 0;
      var totalSynced = 0;
      for (final dog in dogs) {
        final notifier = _ref.read(voiceCommandsProvider(dog.id).notifier);
        final state = _ref.read(voiceCommandsProvider(dog.id));
        final pending = state.commands.values
            .where((c) => c.localPath != null && !c.isSynced)
            .length;
        if (pending == 0) continue;
        totalPending += pending;
        final synced = await notifier.syncAll();
        totalSynced += synced;
      }
      if (totalPending > 0) {
        print('VoiceCommands: auto-sync on reconnect '
            '— $totalSynced/$totalPending pushed across ${dogs.length} dogs');
      }
    } catch (e) {
      print('VoiceCommands: auto-sync error: $e');
    }
  }

  void dispose() {
    _wsSub?.cancel();
  }
}
