import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/services/local_connection_service.dart';
import '../../../data/datasources/robot_api.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/push_to_talk_provider.dart';
import '../../../domain/providers/volume_provider.dart';
import '../../theme/app_theme.dart';

/// Provider to track current lighting pattern index
final _lightingIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to track blue mood LED state (Build 42)
final _blueLedOnProvider = StateProvider<bool>((ref) => false);

/// Provider to track if audio is playing (synced from robot)
final _isPlayingProvider = StateProvider<bool>((ref) => false);

/// Provider to track current track name (synced from robot)
final _currentTrackProvider = StateProvider<String?>((ref) => null);

/// Provider to track playlist index (synced from robot)
final _playlistIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to track playlist length (synced from robot)
final _playlistLengthProvider = StateProvider<int>((ref) => 0);

class QuickActions extends ConsumerStatefulWidget {
  const QuickActions({super.key});

  @override
  ConsumerState<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<QuickActions> {
  StreamSubscription? _audioStateSubscription;

  // Debounce tracking for voice buttons (prevents command queue buildup)
  static const _voiceDebounceMs = 500;
  DateTime? _lastGood;
  DateTime? _lastCallDog;
  DateTime? _lastWantTreat;
  DateTime? _lastNo;
  DateTime? _lastQuiet;
  DateTime? _lastSit;

  bool _canExecuteVoice(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime).inMilliseconds > _voiceDebounceMs;
  }

  StreamSubscription? _uploadResultSubscription;
  // Build 36: Upload timeout tracking
  Timer? _uploadTimeoutTimer;
  String? _pendingUploadFilename;

  // Build 41: Listen for song deletion events
  StreamSubscription? _songDeletedSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for audio_state events from robot to sync UI. Build 146: also
    // initial_status — its audio_status dict seeds playback state on every
    // (re)connect so the UI starts in sync instead of assuming stopped.
    _audioStateSubscription = ref
        .read(websocketClientProvider)
        .eventStream
        .where((event) =>
            event.type == 'audio_state' || event.type == 'initial_status')
        .listen(_handleAudioState);

    // Build 34: Listen for upload result events
    _uploadResultSubscription = ref
        .read(websocketClientProvider)
        .eventStream
        .where((event) =>
            event.type == 'upload_complete' ||
            event.type == 'upload_error' ||
            event.type == 'upload_result')
        .listen(_handleUploadResult);

    // Build 41: Listen for song deleted events
    _songDeletedSubscription = ref
        .read(websocketClientProvider)
        .eventStream
        .where((event) => event.type == 'song_deleted')
        .listen(_handleSongDeleted);
  }

  void _handleSongDeleted(dynamic event) {
    final data = event.data as Map<String, dynamic>;
    final success = data['success'] as bool? ?? true;
    final filename = data['filename'] as String? ?? 'song';

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$filename"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = data['error'] as String? ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleUploadResult(dynamic event) {
    // Build 36: Cancel timeout timer when we get a result
    _uploadTimeoutTimer?.cancel();
    _uploadTimeoutTimer = null;
    _pendingUploadFilename = null;

    final data = event.data as Map<String, dynamic>;
    final success = data['success'] as bool? ?? (event.type == 'upload_complete');
    final filename = data['filename'] as String? ?? 'file';
    final error = data['error'] as String?;

    print('[UPLOAD] Result event: type=${event.type}, success=$success, filename=$filename, error=$error');

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "$filename" successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleAudioState(dynamic event) {
    // event is WsEvent with type 'audio_state' — or 'initial_status', whose
    // audio_status field carries the same shape (usb_audio.get_status()).
    var data = event.data as Map<String, dynamic>;
    if (event.type == 'initial_status') {
      final audioStatus = data['audio_status'];
      if (audioStatus is! Map) return;
      data = Map<String, dynamic>.from(audioStatus);
    } else if (event.buffered == true) {
      // Build 146: the relay latches the LATEST audio_state and replays that
      // ONE frame at connect time (buffered:true, 24h window, relay commits
      // 2026-07-26) so a session joining mid-playback starts in sync. It is
      // by construction the freshest state the relay knows and always arrives
      // before any live frame on the socket — accept it as the seed. (No
      // stale-flood risk: latest-only latch, never feed history.)
      print('[AUDIO_STATE] seeding from relay-latched replay');
    }

    // Update playing state
    final playing = data['playing'] as bool? ?? false;
    ref.read(_isPlayingProvider.notifier).state = playing;

    // Update track name
    final track = data['track'] as String?;
    ref.read(_currentTrackProvider.notifier).state = track;

    // Update playlist info
    final playlistIndex = data['playlist_index'] as int? ?? 0;
    final playlistLength = data['playlist_length'] as int? ?? 0;
    ref.read(_playlistIndexProvider.notifier).state = playlistIndex;
    ref.read(_playlistLengthProvider.notifier).state = playlistLength;

    print('[AUDIO_STATE] playing=$playing, track=$track, index=$playlistIndex/$playlistLength');
  }

  @override
  void dispose() {
    _audioStateSubscription?.cancel();
    _uploadResultSubscription?.cancel();
    _uploadTimeoutTimer?.cancel();
    _songDeletedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treatControl = ref.watch(treatControlProvider);
    final ledControl = ref.watch(ledControlProvider);
    final audioControl = ref.watch(audioControlProvider);
    final lightingIndex = ref.watch(_lightingIndexProvider);
    final isPlaying = ref.watch(_isPlayingProvider);

    final selectedDog = ref.watch(selectedDogProvider);
    final ws = ref.read(websocketClientProvider);
    final blueLedOn = ref.watch(_blueLedOnProvider);

    final pttState = ref.watch(pushToTalkProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick actions, two rows. Row 1 groups the ACTIONS (Talk = live
        // audio, Treat = dispense) left of a divider — they're not canned
        // sounds. Everything right of the divider + all of row 2 are the
        // pre-recorded voice commands.
        Row(
          children: [
            // PTT mic button (hold to talk)
            Expanded(child: _PttActionButton(state: pttState)),

            Expanded(
              child: _ActionButton(
                icon: Icons.pets,
                label: 'Treat',
                color: AppTheme.accent,
                onPressed: () => treatControl.dispense(),
              ),
            ),

            // Divider: actions | voice sounds
            Container(
              width: 1,
              height: 44,
              color: AppTheme.textTertiary.withOpacity(0.3),
            ),

            Expanded(
              child: _ActionButton(
                icon: Icons.thumb_up,
                label: 'Good',
                color: Colors.green,
                onPressed: () {
                  if (selectedDog == null) { _showNoDogError(context); return; }
                  if (!_canExecuteVoice(_lastGood)) return;
                  _lastGood = DateTime.now();
                  ws.sendPlayVoice('good', dogId: selectedDog.id);
                },
              ),
            ),

            Expanded(
              child: _ActionButton(
                icon: Icons.campaign,
                label: 'Call Dog',
                color: Colors.deepOrange,
                onPressed: () {
                  if (selectedDog == null) { _showNoDogError(context); return; }
                  if (!_canExecuteVoice(_lastCallDog)) return;
                  _lastCallDog = DateTime.now();
                  ws.sendCallDog(dogId: selectedDog.id, dogName: selectedDog.name);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Voice command row 2: Want? / No / Quiet / Sit
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.restaurant,
                label: 'Want?',
                color: Colors.amber,
                onPressed: () {
                  if (selectedDog == null) { _showNoDogError(context); return; }
                  if (!_canExecuteVoice(_lastWantTreat)) return;
                  _lastWantTreat = DateTime.now();
                  ws.sendPlayVoice('treat', dogId: selectedDog.id);
                },
              ),
            ),

            Expanded(
              child: _ActionButton(
                icon: Icons.block,
                label: 'No',
                color: Colors.red,
                onPressed: () {
                  if (selectedDog == null) { _showNoDogError(context); return; }
                  if (!_canExecuteVoice(_lastNo)) return;
                  _lastNo = DateTime.now();
                  ledControl.setPattern(LedPatterns.warning);
                  ws.sendPlayVoice('no', dogId: selectedDog.id);
                },
              ),
            ),

            Expanded(
              child: _ActionButton(
                icon: Icons.volume_off,
                label: 'Quiet',
                color: Colors.purpleAccent,
                onPressed: () {
                  if (selectedDog == null) { _showNoDogError(context); return; }
                  if (!_canExecuteVoice(_lastQuiet)) return;
                  _lastQuiet = DateTime.now();
                  ws.sendPlayVoice('quiet', dogId: selectedDog.id);
                },
              ),
            ),

            Expanded(
              child: _ActionButton(
                icon: Icons.airline_seat_recline_normal,
                label: 'Sit',
                color: Colors.lightBlue,
                onPressed: () {
                  if (selectedDog == null) { _showNoDogError(context); return; }
                  if (!_canExecuteVoice(_lastSit)) return;
                  _lastSit = DateTime.now();
                  ws.sendPlayVoice('sit', dogId: selectedDog.id);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Consolidated secondary row: [Lighting | BluLight] — [Music controls]
        Row(
          children: [
            // Light controls (left side)
            _LightingButton(
              currentIndex: lightingIndex,
              onPressed: () {
                final patterns = LedPatterns.lightingCycle;
                final newIndex = (lightingIndex + 1) % patterns.length;
                // A-LED: the snackbar used to announce the new pattern even
                // when the send was silently dropped. Report what happened.
                final sent = ledControl.setPattern(patterns[newIndex]);
                if (sent) {
                  ref.read(_lightingIndexProvider.notifier).state = newIndex;
                }
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(sent
                        ? 'LED: ${_getPatternDisplayName(patterns[newIndex])}'
                        : 'Not connected — LED not sent'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    width: sent ? 150 : 220,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _BluLightButton(
              isOn: blueLedOn,
              onPressed: () {
                final newState = !blueLedOn;
                // A-LED: route through LedControl so BluLight gets the same
                // connection guard + drop trace as the other LED commands.
                if (ref.read(ledControlProvider).setMood(newState)) {
                  ref.read(_blueLedOnProvider.notifier).state = newState;
                }
              },
            ),

            const SizedBox(width: 12),

            // Music controls (right side, takes remaining space)
            Expanded(
              child: _MusicControlsWithVolume(
                isPlaying: isPlaying,
                trackName: ref.watch(_currentTrackProvider),
                onPrev: () => audioControl.prev(),
                onToggle: () {
                  // Build 146: NO optimistic flip. Robot contract 60e526f:
                  // playback state renders only from audio_state events
                  // (seeded by initial_status.audio_status) — a command that
                  // failed robot-side ("Audio is loading") did nothing, and
                  // the old local flip is exactly the play/pause inversion
                  // bug. audio_state now arrives over /ws/local too.
                  audioControl.toggle();
                },
                onNext: () => audioControl.next(),
                onUpload: () => _pickAndUploadSong(context, ref),
                onDeleteTrack: (trackPath) => _confirmDeleteSong(trackPath),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build 38: Max file size for MP3 uploads (20MB to match robot download_song limit)
  static const _maxUploadSizeBytes = 20 * 1024 * 1024;

  Future<void> _pickAndUploadSong(BuildContext context, WidgetRef ref) async {
    try {
      print('[UPLOAD] Opening file picker...');

      // IMPORTANT: Use FileType.custom with explicit extensions
      // DO NOT use FileType.audio - it opens Apple Music on iOS and crashes
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],  // Only MP3 files
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        print('[UPLOAD] User cancelled');
        return;
      }

      final file = result.files.first;
      print('[UPLOAD] Selected: ${file.name}, size: ${file.size} bytes');

      // Validate extension
      if (!file.name.toLowerCase().endsWith('.mp3')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an MP3 file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check we have a valid path
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Build 38: Check file size BEFORE reading to avoid memory issues
      if (file.size > _maxUploadSizeBytes) {
        print('[UPLOAD] File too large: ${file.size} bytes > $_maxUploadSizeBytes');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large (max 20MB)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Skip upload in local mode — relay upload endpoint not available
      final localConn = ref.read(localConnectionProvider);
      if (localConn.isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Music upload not available in local mode'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Build 38: Get auth token and dog ID for HTTP upload
      final token = ref.read(authTokenProvider);
      final selectedDog = ref.read(selectedDogProvider);

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not authenticated - please login'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (selectedDog == null) {
        if (mounted) {
          _showNoDogError(context);
        }
        return;
      }

      final filePath = file.path!;
      final filename = file.name;
      final dogId = selectedDog.id;

      // Build 40: Get device_id - relay requires all 3 form fields
      final deviceId = ref.read(deviceIdProvider);

      print('[UPLOAD] Build 40: Starting HTTP multipart upload');
      print('[UPLOAD]   filename: $filename');
      print('[UPLOAD]   dogId: $dogId');
      print('[UPLOAD]   deviceId: $deviceId');
      print('[UPLOAD]   size: ${file.size} bytes');

      // Show initial upload indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Uploading "$filename"...'),
              ],
            ),
            duration: const Duration(minutes: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Build 40: Upload via HTTP multipart with all 3 required fields
      final robotApi = ref.read(robotApiProvider);
      final error = await robotApi.uploadMusic(
        token: token,
        filePath: filePath,
        filename: filename,
        dogId: dogId,
        deviceId: deviceId,
        onProgress: (sent, total) {
          final percent = (sent / total * 100).toStringAsFixed(0);
          print('[UPLOAD] Progress: $percent% ($sent/$total bytes)');
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (error == null) {
        // Success
        print('[UPLOAD] HTTP upload successful');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "$filename" successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Error
        print('[UPLOAD] HTTP upload failed: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (e) {
      print('[UPLOAD] Platform error: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('[UPLOAD] Error: $e');
      print('[UPLOAD] Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNoDogError(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a dog first'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build 41: Delete current song with confirmation
  void _confirmDeleteSong(String trackPath) {
    final displayName = _extractTrackDisplayName(trackPath);
    final selectedDog = ref.read(selectedDogProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Delete "$displayName" from the playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Extract filename from path (e.g., "default/song.mp3" -> "song.mp3")
              final filename = trackPath.split('/').last;
              ref.read(websocketClientProvider).sendDeleteSong(
                filename,
                dogId: selectedDog?.id,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleting "$displayName"...'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _extractTrackDisplayName(String trackPath) {
    if (trackPath.isEmpty) return '';
    final parts = trackPath.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  String _getPatternDisplayName(String pattern) {
    switch (pattern) {
      case LedPatterns.rainbow:
        return 'Rainbow';
      case LedPatterns.fire:
        return 'Fire';
      case LedPatterns.solidBlue:
        return 'Blue';
      case LedPatterns.chase:
        return 'Chase';
      case LedPatterns.ambient:
        return 'Ambient';
      case LedPatterns.off:
        return 'Off';
      default:
        return pattern;
    }
  }
}

/// PTT action button — single tap to record 5s, auto-sends
class _PttActionButton extends ConsumerWidget {
  final PttStateData state;

  const _PttActionButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = state.isRecording;
    final isSending = state.state == PttState.sending;
    final isBusy = isRecording || isSending;

    // Countdown
    final remainingMs = PushToTalkNotifier.maxRecordingDurationMs - state.recordingDurationMs;
    final remainingSec = (remainingMs / 1000).ceil().clamp(0, 5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isBusy ? null : () async {
            HapticFeedback.mediumImpact();
            final success = await ref.read(pushToTalkProvider.notifier).startRecording();
            if (!success) {
              HapticFeedback.heavyImpact();
            }
          },
          child: Material(
            color: isRecording
                ? Colors.red.withOpacity(0.3)
                : (isBusy ? Colors.grey.withOpacity(0.1) : Colors.cyan.withOpacity(0.1)),
            shape: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isRecording
                  ? Text('$remainingSec', style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold))
                  : Icon(
                      isSending ? Icons.upload : Icons.mic_none,
                      color: isSending ? Colors.grey : Colors.cyan,
                      size: 22,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isRecording ? 'Recording' : 'Talk',
          style: TextStyle(
            fontSize: 10,
            color: isRecording ? Colors.red : Colors.cyan,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Standard action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withOpacity(0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Lighting button with cycle indicator
class _LightingButton extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onPressed;

  const _LightingButton({
    required this.currentIndex,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final patterns = LedPatterns.lightingCycle;
    final isOff = patterns[currentIndex] == LedPatterns.off;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.orange.withOpacity(0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                isOff ? Icons.lightbulb_outline : Icons.lightbulb,
                color: Colors.orange,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lighting',
          style: TextStyle(
            fontSize: 11,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Pattern indicator dots
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            patterns.length,
            (i) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == currentIndex
                    ? Colors.orange
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Build 42: Blue mood LED toggle button
class _BluLightButton extends StatelessWidget {
  final bool isOn;
  final VoidCallback onPressed;

  const _BluLightButton({
    required this.isOn,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.blue.withOpacity(isOn ? 0.3 : 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                color: Colors.blue,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'BluLight',
          style: TextStyle(
            fontSize: 11,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
        // On/Off indicator
        const SizedBox(height: 2),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn ? Colors.blue : Colors.blue.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}

/// System-audio volume slider. Reconciled to the robot's telemetry volume
/// (the single source of truth in VolumeManager) — see [volumeProvider].
/// Shows a sync indicator until the robot confirms a user change.
class _VolumeSlider extends ConsumerWidget {
  const _VolumeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider);
    final level = volume.level ?? 60; // 60 = VolumeManager's documented default
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 140,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level == 0 ? Icons.volume_off : Icons.volume_down,
            size: 14,
            color: primary.withOpacity(0.7),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: primary,
                inactiveTrackColor: primary.withOpacity(0.2),
                thumbColor: primary,
              ),
              child: Slider(
                value: level.toDouble(),
                min: 0,
                max: 100,
                // Drag → optimistic preview; release → send to the robot.
                onChanged: (v) =>
                    ref.read(volumeProvider.notifier).preview(v.toInt()),
                onChangeEnd: (v) =>
                    ref.read(volumeProvider.notifier).commit(v.toInt()),
              ),
            ),
          ),
          // Trailing: volume icon, or a sync spinner while awaiting the
          // robot's telemetry confirmation of a user change.
          SizedBox(
            width: 14,
            height: 14,
            child: volume.syncing
                ? CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor:
                        AlwaysStoppedAnimation(primary.withOpacity(0.7)),
                  )
                : Icon(
                    Icons.volume_up,
                    size: 14,
                    color: primary.withOpacity(0.7),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Music playback controls with volume slider
class _MusicControlsWithVolume extends StatelessWidget {
  final bool isPlaying;
  final String? trackName;
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback? onUpload;
  // Build 41: Callback for deleting current track
  final void Function(String trackPath)? onDeleteTrack;

  const _MusicControlsWithVolume({
    required this.isPlaying,
    this.trackName,
    required this.onPrev,
    required this.onToggle,
    required this.onNext,
    this.onUpload,
    this.onDeleteTrack,
  });

  /// Extract display name from track path (e.g., "default/Wimz_theme.mp3" → "Wimz_theme")
  String _getTrackDisplayName() {
    if (trackName == null || trackName!.isEmpty) return '';
    // Extract filename without path and extension
    final parts = trackName!.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getTrackDisplayName();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transport controls row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Music icon - animated when playing
              Icon(
                isPlaying ? Icons.music_note : Icons.music_off,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),

              // Previous button
              _MusicButton(
                icon: Icons.skip_previous,
                onPressed: onPrev,
              ),

              const SizedBox(width: 4),

              // Play/Pause button - icon changes based on state
              _MusicButton(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                onPressed: onToggle,
                isPrimary: true,
              ),

              const SizedBox(width: 4),

              // Next button
              _MusicButton(
                icon: Icons.skip_next,
                onPressed: onNext,
              ),

              if (onUpload != null) ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                const SizedBox(width: 8),
                // Upload button
                _MusicButton(
                  icon: Icons.file_upload,
                  onPressed: onUpload!,
                ),
              ],
            ],
          ),
        ),
        // Track name display (when playing)
        // Build 41: Long-press to delete the track
        if (displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onLongPress: onDeleteTrack != null && trackName != null
                ? () => onDeleteTrack!(trackName!)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (onDeleteTrack != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.more_vert,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const _VolumeSlider(),
      ],
    );
  }
}

/// Individual music control button
class _MusicButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _MusicButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: isPrimary ? color.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(isPrimary ? 10 : 8),
          child: Icon(
            icon,
            color: color,
            size: isPrimary ? 24 : 20,
          ),
        ),
      ),
    );
  }
}
