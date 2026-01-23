import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../domain/providers/control_provider.dart';
import '../../theme/app_theme.dart';

/// Provider to track current lighting pattern index
final _lightingIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to track if audio is playing
final _isPlayingProvider = StateProvider<bool>((ref) => false);

class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatControl = ref.watch(treatControlProvider);
    final ledControl = ref.watch(ledControlProvider);
    final audioControl = ref.watch(audioControlProvider);
    final lightingIndex = ref.watch(_lightingIndexProvider);
    final isPlaying = ref.watch(_isPlayingProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main action buttons row - [Good] [Give Treat] [Want Treat?] [No]
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Good button - plays good_dog.mp3
            _ActionButton(
              icon: Icons.thumb_up,
              label: 'Good',
              color: Colors.green,
              onPressed: () {
                audioControl.play('good_dog.mp3');
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

            // Want Treat? button - plays treat.mp3 audio
            _ActionButton(
              icon: Icons.restaurant,
              label: 'Want Treat?',
              color: Colors.amber,
              onPressed: () {
                audioControl.play('treat.mp3');
              },
            ),

            // No button - warning LED + no.mp3
            _ActionButton(
              icon: Icons.block,
              label: 'No',
              color: Colors.red,
              onPressed: () {
                ledControl.setPattern(LedPatterns.warning);
                audioControl.play('no.mp3');
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

            // Music controls row
            // Prev/Next load songs but don't auto-play
            // Play/Pause toggles playback state
            _MusicControls(
              isPlaying: isPlaying,
              onPrev: () {
                audioControl.prev();
                // Prev loads song but doesn't play - keep current state
              },
              onToggle: () {
                audioControl.toggle();
                ref.read(_isPlayingProvider.notifier).state = !isPlaying;
              },
              onNext: () {
                audioControl.next();
                // Next loads song but doesn't play - keep current state
              },
            ),
          ],
        ),
      ],
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

/// Music playback controls
class _MusicControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  const _MusicControls({
    required this.isPlaying,
    required this.onPrev,
    required this.onToggle,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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

          // Play/Pause button
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
        ],
      ),
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
