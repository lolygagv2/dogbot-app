import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

/// Provider to track if audio is playing
final _isPlayingProvider = StateProvider<bool>((ref) => false);

/// Provider to track current track name
final _currentTrackProvider = StateProvider<String?>((ref) => null);

/// Provider to track volume level (0-100)
final _volumeProvider = StateProvider<int>((ref) => 70);

class QuickActions extends ConsumerStatefulWidget {
  const QuickActions({super.key});

  @override
  ConsumerState<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<QuickActions> {
  Timer? _volumeDebounce;

  @override
  void dispose() {
    _volumeDebounce?.cancel();
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

    final callDogControl = ref.watch(callDogProvider);
    final selectedDog = ref.watch(selectedDogProvider);
    final ws = ref.read(websocketClientProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main action buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Good button - plays voice command on robot
            _ActionButton(
              icon: Icons.thumb_up,
              label: 'Good',
              color: Colors.green,
              onPressed: () {
                ws.sendPlayVoice('good', dogId: selectedDog?.id);
              },
            ),

            // Call Dog button - plays recall sound
            _ActionButton(
              icon: Icons.campaign,
              label: 'Call Dog',
              color: Colors.deepOrange,
              onPressed: () {
                callDogControl.call();
              },
            ),

            // Give Treat button - dispenses treat only
            _ActionButton(
              icon: Icons.pets,
              label: 'Give Treat',
              color: AppTheme.accent,
              onPressed: () {
                treatControl.dispense();
              },
            ),

            // Want Treat? button - plays voice command on robot
            _ActionButton(
              icon: Icons.restaurant,
              label: 'Want Treat?',
              color: Colors.amber,
              onPressed: () {
                ws.sendPlayVoice('treat', dogId: selectedDog?.id);
              },
            ),

            // No button - warning LED + voice command on robot
            _ActionButton(
              icon: Icons.block,
              label: 'No',
              color: Colors.red,
              onPressed: () {
                ledControl.setPattern(LedPatterns.warning);
                ws.sendPlayVoice('no', dogId: selectedDog?.id);
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
            _MusicControlsWithVolume(
              isPlaying: isPlaying,
              volume: ref.watch(_volumeProvider),
              onPrev: () {
                audioControl.prev();
                ref.read(_isPlayingProvider.notifier).state = true;
                _showTrackToast(context, 'Skipped back');
              },
              onToggle: () {
                audioControl.toggle();
                ref.read(_isPlayingProvider.notifier).state = !isPlaying;
              },
              onNext: () {
                audioControl.next();
                ref.read(_isPlayingProvider.notifier).state = true;
                _showTrackToast(context, 'Skipped forward');
              },
              onVolumeChanged: _onVolumeChanged,
              onUpload: () => _pickAndUploadSong(context, ref),
            ),
          ],
        ),
      ],
    );
  }

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

      final bytes = await File(file.path!).readAsBytes();
      print('[UPLOAD] Read ${bytes.length} bytes');

      final base64Data = base64Encode(bytes);
      final filename = file.name;
      final format = file.extension ?? 'mp3';

      ref.read(websocketClientProvider).sendUploadSong(filename, base64Data, format);

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
    } on PlatformException catch (e) {
      print('[UPLOAD] Platform error: ${e.code} - ${e.message}');
      if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTrackToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        width: 180,
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
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final ValueChanged<int> onVolumeChanged;
  final VoidCallback? onUpload;

  const _MusicControlsWithVolume({
    required this.isPlaying,
    required this.volume,
    required this.onPrev,
    required this.onToggle,
    required this.onNext,
    required this.onVolumeChanged,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
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
              // Music icon
              Icon(
                Icons.music_note,
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
