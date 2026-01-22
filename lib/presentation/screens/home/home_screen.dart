import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../../domain/providers/control_provider.dart';
import '../../widgets/video/webrtc_video_view.dart';
import '../../widgets/status/battery_indicator.dart';
import '../../widgets/status/connection_badge.dart';
import '../../widgets/controls/quick_actions.dart';
import '../../theme/app_theme.dart';

/// Main dashboard screen with video and quick controls
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final telemetry = ref.watch(telemetryProvider);
    final deviceId = ref.watch(deviceIdProvider);

    // Redirect if disconnected
    if (!connection.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/connect');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WIM-Z'),
            Text(
              deviceId,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          const ConnectionBadge(),
          const SizedBox(width: 8),
          BatteryIndicator(level: telemetry.battery),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Video stream
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Use WebRTC for video streaming via relay
                  const WebRTCVideoView(),

                  // Detection overlay
                  if (telemetry.dogDetected)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: _DetectionChip(
                        behavior: telemetry.currentBehavior,
                        confidence: telemetry.confidence,
                      ),
                    ),

                  // Mode indicator
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _ModeChip(mode: telemetry.mode),
                  ),
                ],
              ),
            ),
          ),

          // Quick controls
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick action buttons
                  const QuickActions(),
                  const SizedBox(height: 16),

                  // Navigation buttons
                  Row(
                    children: [
                      Expanded(
                        child: _NavButton(
                          icon: Icons.gamepad,
                          label: 'Drive',
                          onTap: () => context.push('/drive'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NavButton(
                          icon: Icons.school,
                          label: 'Missions',
                          onTap: () => context.push('/missions'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NavButton(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () => context.push('/settings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detection status chip
class _DetectionChip extends StatelessWidget {
  final String? behavior;
  final double? confidence;

  const _DetectionChip({this.behavior, this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getBehaviorColor(behavior);
    final confidenceText =
        confidence != null ? '${(confidence! * 100).toInt()}%' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pets, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            behavior?.toUpperCase() ?? 'DETECTED',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (confidenceText.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              confidenceText,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mode indicator chip
class _ModeChip extends StatelessWidget {
  final String mode;

  const _ModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mode.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Navigation button
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
