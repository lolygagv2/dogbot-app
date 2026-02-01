import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/websocket_client.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../theme/app_theme.dart';

/// Provider to track current lighting pattern index
final _lightingIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to track if audio is playing (synced from robot)
final _isPlayingProvider = StateProvider<bool>((ref) => false);

/// Provider to track current track name (synced from robot)
final _currentTrackProvider = StateProvider<String?>((ref) => null);

/// Provider to track playlist index (synced from robot)
final _playlistIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to track playlist length (synced from robot)
final _playlistLengthProvider = StateProvider<int>((ref) => 0);

/// Provider to track volume level (0-100)
final _volumeProvider = StateProvider<int>((ref) => 70);

class QuickActions extends ConsumerStatefulWidget {
  const QuickActions({super.key});

  @override
  ConsumerState<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<QuickActions> {
  Timer? _volumeDebounce;
  StreamSubscription? _audioStateSubscription;

  // Debounce tracking for voice buttons (prevents command queue buildup)
  static const _voiceDebounceMs = 500;
  DateTime? _lastGood;
  DateTime? _lastCallDog;
  DateTime? _lastWantTreat;
  DateTime? _lastNo;

  bool _canExecuteVoice(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime).inMilliseconds > _voiceDebounceMs;
  }

  StreamSubscription? _uploadResultSubscription;
  // Build 36: Upload timeout tracking
  Timer? _uploadTimeoutTimer;
  String? _pendingUploadFilename;

  @override
  void initState() {
    super.initState();
    // Listen for audio_state events from robot to sync UI
    _audioStateSubscription = ref
        .read(websocketClientProvider)
        .eventStream
        .where((event) => event.type == 'audio_state')
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
    // event is WsEvent with type 'audio_state'
    final data = event.data as Map<String, dynamic>;

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
    _volumeDebounce?.cancel();
    _audioStateSubscription?.cancel();
    _uploadResultSubscription?.cancel();
    _uploadTimeoutTimer?.cancel();
    super.dispose();
  }

  void _onVolumeChanged(int volume) {
    // Update UI immediately for responsive feel
    ref.read(_volumeProvider.notifier).state = volume;

    // Debounce the actual command to the robot
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 200), () {
      ref.read(audioControlProvider).setVolume(volume);
    });
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main action buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Good button - plays voice command on robot (debounced)
            _ActionButton(
              icon: Icons.thumb_up,
              label: 'Good',
              color: Colors.green,
              onPressed: () {
                if (selectedDog == null) {
                  _showNoDogError(context);
                  return;
                }
                if (!_canExecuteVoice(_lastGood)) return;
                _lastGood = DateTime.now();
                ws.sendPlayVoice('good', dogId: selectedDog.id);
              },
            ),

            // Call Dog button - plays recall sound (debounced)
            _ActionButton(
              icon: Icons.campaign,
              label: 'Call Dog',
              color: Colors.deepOrange,
              onPressed: () {
                if (selectedDog == null) {
                  _showNoDogError(context);
                  return;
                }
                if (!_canExecuteVoice(_lastCallDog)) return;
                _lastCallDog = DateTime.now();
                ws.sendCallDog(dogId: selectedDog.id, dogName: selectedDog.name);
              },
            ),

            // Give Treat button - dispenses treat only (debounced in provider)
            _ActionButton(
              icon: Icons.pets,
              label: 'Give Treat',
              color: AppTheme.accent,
              onPressed: () {
                treatControl.dispense();
              },
            ),

            // Want Treat? button - plays voice command on robot (debounced)
            _ActionButton(
              icon: Icons.restaurant,
              label: 'Want Treat?',
              color: Colors.amber,
              onPressed: () {
                if (selectedDog == null) {
                  _showNoDogError(context);
                  return;
                }
                if (!_canExecuteVoice(_lastWantTreat)) return;
                _lastWantTreat = DateTime.now();
                ws.sendPlayVoice('treat', dogId: selectedDog.id);
              },
            ),

            // No button - warning LED + voice command on robot (debounced)
            _ActionButton(
              icon: Icons.block,
              label: 'No',
              color: Colors.red,
              onPressed: () {
                if (selectedDog == null) {
                  _showNoDogError(context);
                  return;
                }
                if (!_canExecuteVoice(_lastNo)) return;
                _lastNo = DateTime.now();
                ledControl.setPattern(LedPatterns.warning);
                ws.sendPlayVoice('no', dogId: selectedDog.id);
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Secondary row - Lighting and Music controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lighting button - cycles through patterns
            _LightingButton(
              currentIndex: lightingIndex,
              onPressed: () {
                final patterns = LedPatterns.lightingCycle;
                final newIndex = (lightingIndex + 1) % patterns.length;
                ref.read(_lightingIndexProvider.notifier).state = newIndex;
                ledControl.setPattern(patterns[newIndex]);

                // Show pattern name briefly
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('LED: ${_getPatternDisplayName(patterns[newIndex])}'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    width: 150,
                  ),
                );
              },
            ),

            const SizedBox(width: 24),

            // Music controls row with volume
            // State synced from robot via audio_state WebSocket events
            _MusicControlsWithVolume(
              isPlaying: isPlaying,
              volume: ref.watch(_volumeProvider),
              trackName: ref.watch(_currentTrackProvider),
              onPrev: () {
                audioControl.prev();
                // Don't set local state - wait for audio_state event from robot
              },
              onToggle: () {
                audioControl.toggle();
                // Don't set local state - wait for audio_state event from robot
              },
              onNext: () {
                audioControl.next();
                // Don't set local state - wait for audio_state event from robot
              },
              onVolumeChanged: _onVolumeChanged,
              onUpload: () => _pickAndUploadSong(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  // Build 34: Max file size for MP3 uploads (10MB)
  static const _maxUploadSizeBytes = 10 * 1024 * 1024;

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

      // Build 34: Check file size BEFORE reading to avoid memory issues
      if (file.size > _maxUploadSizeBytes) {
        print('[UPLOAD] File too large: ${file.size} bytes > $_maxUploadSizeBytes');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large (max 10MB)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Build 34: Show uploading indicator early
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
                Text('Reading "${file.name}"...'),
              ],
            ),
            duration: const Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Build 34: Read file in isolate to not block main thread
      // This prevents WebSocket disconnects during large file reads
      final filePath = file.path!;
      final bytes = await compute(_readFileBytes, filePath);
      print('[UPLOAD] Read ${bytes.length} bytes from file (via isolate)');

      // Encode in isolate as well to prevent UI blocking
      final base64Data = await compute(base64Encode, bytes);
      final filename = file.name;
      final format = file.extension ?? 'mp3';

      print('[UPLOAD] Preparing WebSocket command:');
      print('[UPLOAD]   filename: $filename');
      print('[UPLOAD]   format: $format');
      print('[UPLOAD]   raw bytes: ${bytes.length}');
      print('[UPLOAD]   base64 length: ${base64Data.length}');
      print('[UPLOAD] Sending upload_song command via WebSocket...');

      // Build 34: Wrap send in try-catch to prevent connection loss on send failure
      try {
        ref.read(websocketClientProvider).sendUploadSong(filename, base64Data, format);
        print('[UPLOAD] Command sent - check robot logs for upload_song handling');

        // Build 36: Start timeout timer - show warning if no response in 10 seconds
        _pendingUploadFilename = filename;
        _uploadTimeoutTimer?.cancel();
        _uploadTimeoutTimer = Timer(const Duration(seconds: 10), () {
          if (mounted && _pendingUploadFilename != null) {
            print('[UPLOAD] Timeout - no response received for $_pendingUploadFilename');
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload of "$_pendingUploadFilename" may have failed - no response from server'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
            _pendingUploadFilename = null;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploading "$filename" to robot...'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (sendError) {
        print('[UPLOAD] Send error (connection preserved): $sendError');
        _uploadTimeoutTimer?.cancel();
        _pendingUploadFilename = null;
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send: $sendError'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  /// Isolate function to read file bytes without blocking main thread
  static List<int> _readFileBytes(String path) {
    return File(path).readAsBytesSync();
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
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
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

/// Music playback controls with volume slider
class _MusicControlsWithVolume extends StatelessWidget {
  final bool isPlaying;
  final int volume;
  final String? trackName;
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final ValueChanged<int> onVolumeChanged;
  final VoidCallback? onUpload;

  const _MusicControlsWithVolume({
    required this.isPlaying,
    required this.volume,
    this.trackName,
    required this.onPrev,
    required this.onToggle,
    required this.onNext,
    required this.onVolumeChanged,
    this.onUpload,
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
        if (displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
        const SizedBox(height: 8),
        // Volume slider
        SizedBox(
          width: 140,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                volume == 0 ? Icons.volume_off : Icons.volume_down,
                size: 14,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Slider(
                    value: volume.toDouble(),
                    min: 0,
                    max: 100,
                    onChanged: (v) => onVolumeChanged(v.toInt()),
                  ),
                ),
              ),
              Icon(
                Icons.volume_up,
                size: 14,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
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
