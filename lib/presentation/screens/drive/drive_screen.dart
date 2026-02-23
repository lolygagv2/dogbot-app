import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:go_router/go_router.dart';

import '../../../domain/providers/coach_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../widgets/video/webrtc_video_view.dart';
import '../../widgets/video/audio_mute_toggle.dart';
import '../../widgets/controls/push_to_talk.dart';
import '../../theme/app_theme.dart';

class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen> {
  bool _modeChangeRequested = false;

  @override
  void initState() {
    super.initState();
    // Keep screen on while driving
    WakelockPlus.enable();
    print('DriveScreen: Wakelock enabled');

    // v1.3: Store portrait mode before switching to manual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modeState = ref.read(modeStateProvider);
      if (modeState.isMissionActive || modeState.isModeLocked) {
        print('DriveScreen: Mission active (${modeState.activeMissionName}), keeping mission mode');
      } else if (modeState.currentMode == RobotMode.mission) {
        print('DriveScreen: In mission mode, keeping it');
      } else if (modeState.currentMode == RobotMode.coach) {
        print('DriveScreen: In coach mode, keeping it');
      } else {
        // Store current portrait mode before entering landscape
        ref.read(modeStateProvider.notifier).storePortraitMode();
        _ensureManualMode();
      }
    });
  }

  @override
  void dispose() {
    // Build 38: Removed sendManualControlInactive() - no commands on screen dispose
    // Allow screen to sleep again
    WakelockPlus.disable();
    print('DriveScreen: Wakelock disabled');
    super.dispose();
  }

  void _ensureManualMode() {
    final modeState = ref.read(modeStateProvider);
    if (modeState.currentMode != RobotMode.manual) {
      print('DriveScreen: Not in manual mode, switching...');
      _modeChangeRequested = true;
      ref.read(modeStateProvider.notifier).setManualMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider);
    final motorControl = ref.watch(motorControlProvider.notifier);
    final motorState = ref.watch(motorControlProvider);
    final modeState = ref.watch(modeStateProvider);

    // Check if we're ready to drive (in manual mode and not pending)
    final isMissionActive = modeState.isMissionActive || modeState.currentMode == RobotMode.mission;
    final isReady = (modeState.currentMode == RobotMode.manual &&
        modeState.pendingMode == null) || isMissionActive ||
        modeState.currentMode == RobotMode.coach;

    // Clear mode change request flag when confirmed
    if (_modeChangeRequested && isReady) {
      _modeChangeRequested = false;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            // v1.3: Restore previous portrait mode on exit
            final modeState = ref.read(modeStateProvider);
            if (modeState.currentMode == RobotMode.coach) {
              // Return to coach screen (portrait) — keep coach mode active
              context.go('/coach');
            } else {
              if (!modeState.isMissionActive && !modeState.isModeLocked) {
                ref.read(modeStateProvider.notifier).restorePortraitMode();
              }
              Navigator.of(context).pop();
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        actions: [
          // Emergency Stop button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => motorControl.emergencyStop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emergency, color: Colors.white),
              ),
              tooltip: 'Emergency Stop',
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen video background
          const WebRTCVideoView(),

          // Top status bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Speed indicators
                _CompactSpeedIndicator(
                  leftSpeed: motorState.left,
                  rightSpeed: motorState.right,
                ),
                // v1.3: Landscape mode selector (manual/coach/mission)
                _LandscapeModeSelector(
                  currentMode: modeState.displayMode,
                  isChanging: modeState.isChanging,
                  isMissionActive: isMissionActive,
                ),
                // Detection indicator
                if (telemetry.dogDetected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.getBehaviorColor(telemetry.currentBehavior),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          AppTheme.getBehaviorDisplayName(telemetry.currentBehavior).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Active mission banner
          if (isMissionActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 88,
              left: 16,
              right: 16,
              child: _ActiveMissionBanner(),
            ),

          // Bottom controls - joysticks overlaid (only enabled when ready)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: IgnorePointer(
              ignoring: !isReady,
              child: AnimatedOpacity(
                opacity: isReady ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Drive D-pad (left) - press and hold to accelerate
                    const _MotorDpad(),

                    // Center controls - treat, center, PTT mic
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PTT mic button only (listen replaced by streaming)
                        const PushToTalkMicOnly(compact: true),
                        const SizedBox(height: 16),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _OverlayButton(
                              icon: Icons.campaign,
                              label: 'CALL',
                              onTap: () => ref.read(callDogProvider).call(),
                            ),
                            const SizedBox(width: 12),
                            _OverlayButton(
                              icon: Icons.cookie,
                              label: 'TREAT',
                              onTap: () => ref.read(treatControlProvider).dispense(),
                            ),
                            const SizedBox(width: 12),
                            _OverlayButton(
                              icon: Icons.center_focus_strong,
                              label: 'CENTER',
                              onTap: () => ref.read(servoControlProvider.notifier).center(),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Camera joystick (right)
                    const _OverlayCameraControl(),
                  ],
                ),
              ),
            ),
          ),

          // Audio mute toggle (top-left, below status bar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 16,
            child: const AudioMuteToggle(),
          ),

          // Coach mode trick buttons (landscape overlay)
          if (modeState.currentMode == RobotMode.coach)
            _DriveCoachOverlay(),

          // v1.3: Brief toast overlay during mode transition (auto-dismisses)
          if (!isReady && _modeChangeRequested)
            Positioned(
              top: MediaQuery.of(context).padding.top + 88,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.orange),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Switching mode...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact speed indicator for overlay
class _CompactSpeedIndicator extends StatelessWidget {
  final double leftSpeed;
  final double rightSpeed;

  const _CompactSpeedIndicator({
    required this.leftSpeed,
    required this.rightSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpeedBar(label: 'L', value: leftSpeed),
          const SizedBox(width: 8),
          _SpeedBar(label: 'R', value: rightSpeed),
        ],
      ),
    );
  }
}

class _SpeedBar extends StatelessWidget {
  final String label;
  final double value;

  const _SpeedBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value > 0.05
        ? Colors.green
        : (value < -0.05 ? Colors.red : Colors.grey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: value >= 0 ? Alignment.centerLeft : Alignment.centerRight,
            widthFactor: value.abs().clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Motor D-pad control with acceleration on hold
/// Layout:     [↑]
///        [←] [■] [→]
///            [↓]
class _MotorDpad extends ConsumerStatefulWidget {
  const _MotorDpad();

  @override
  ConsumerState<_MotorDpad> createState() => _MotorDpadState();
}

class _MotorDpadState extends ConsumerState<_MotorDpad> {
  Timer? _accelerationTimer;
  double _currentSpeed = 0.0;
  _MotorDirection? _activeDirection;

  // Speed ramp: 20% -> 40% -> 60% -> 80% -> 100% over 1.5 seconds (100ms intervals = 15 steps)
  static const double _startSpeed = 0.2;
  static const double _maxSpeed = 1.0;
  static const double _speedIncrement = (_maxSpeed - _startSpeed) / 15; // ~0.053 per step
  static const Duration _updateInterval = Duration(milliseconds: 100);

  @override
  void dispose() {
    _accelerationTimer?.cancel();
    super.dispose();
  }

  void _onDirectionStart(_MotorDirection direction) {
    _activeDirection = direction;
    _currentSpeed = _startSpeed;
    _sendMotorCommand();

    // Start acceleration timer
    _accelerationTimer?.cancel();
    _accelerationTimer = Timer.periodic(_updateInterval, (_) {
      if (_currentSpeed < _maxSpeed) {
        _currentSpeed = (_currentSpeed + _speedIncrement).clamp(0.0, _maxSpeed);
      }
      _sendMotorCommand();
    });
  }

  void _onDirectionEnd() {
    _accelerationTimer?.cancel();
    _accelerationTimer = null;
    _activeDirection = null;
    _currentSpeed = 0.0;

    // Send one stop command
    ref.read(motorControlProvider.notifier).setMotorSpeeds(0, 0);
  }

  void _sendMotorCommand() {
    if (_activeDirection == null) return;

    final motorControl = ref.read(motorControlProvider.notifier);
    final speed = _currentSpeed;

    switch (_activeDirection!) {
      case _MotorDirection.forward:
        motorControl.setMotorSpeeds(speed, speed);
        break;
      case _MotorDirection.backward:
        motorControl.setMotorSpeeds(-speed, -speed);
        break;
      case _MotorDirection.left:
        // Turn left: left motor slow/reverse, right motor forward
        motorControl.setMotorSpeeds(-speed, speed);
        break;
      case _MotorDirection.right:
        // Turn right: left motor forward, right motor slow/reverse
        motorControl.setMotorSpeeds(speed, -speed);
        break;
    }
  }

  void _emergencyStop() {
    _accelerationTimer?.cancel();
    _accelerationTimer = null;
    _activeDirection = null;
    _currentSpeed = 0.0;
    ref.read(motorControlProvider.notifier).emergencyStop();
  }

  @override
  Widget build(BuildContext context) {
    final motorState = ref.watch(motorControlProvider);
    final speedPercent = (_currentSpeed * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DRIVE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(78),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Up button (forward)
              Positioned(
                top: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: _MotorDpadButton(
                    icon: Icons.keyboard_arrow_up,
                    isActive: _activeDirection == _MotorDirection.forward,
                    onPressStart: () => _onDirectionStart(_MotorDirection.forward),
                    onPressEnd: _onDirectionEnd,
                  ),
                ),
              ),
              // Down button (backward)
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: _MotorDpadButton(
                    icon: Icons.keyboard_arrow_down,
                    isActive: _activeDirection == _MotorDirection.backward,
                    onPressStart: () => _onDirectionStart(_MotorDirection.backward),
                    onPressEnd: _onDirectionEnd,
                  ),
                ),
              ),
              // Left button (turn left)
              Positioned(
                left: -4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _MotorDpadButton(
                    icon: Icons.keyboard_arrow_left,
                    isActive: _activeDirection == _MotorDirection.left,
                    onPressStart: () => _onDirectionStart(_MotorDirection.left),
                    onPressEnd: _onDirectionEnd,
                  ),
                ),
              ),
              // Right button (turn right)
              Positioned(
                right: -4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _MotorDpadButton(
                    icon: Icons.keyboard_arrow_right,
                    isActive: _activeDirection == _MotorDirection.right,
                    onPressStart: () => _onDirectionStart(_MotorDirection.right),
                    onPressEnd: _onDirectionEnd,
                  ),
                ),
              ),
              // Center button (emergency stop)
              GestureDetector(
                onTap: _emergencyStop,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: motorState.isMoving
                        ? Colors.red.withOpacity(0.8)
                        : AppTheme.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: motorState.isMoving ? Colors.red : AppTheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: motorState.isMoving
                        ? Text(
                            '$speedPercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Icon(Icons.stop, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MotorDirection { forward, backward, left, right }

/// D-pad button for motor control with press/release detection
class _MotorDpadButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const _MotorDpadButton({
    required this.icon,
    required this.isActive,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressStart(),
      onTapUp: (_) => onPressEnd(),
      onTapCancel: onPressEnd,
      child: Container(
        width: 56,
        height: 56,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary
                : AppTheme.primary.withOpacity(0.7),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 8)]
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// Camera pan/tilt D-pad control overlay
/// Each tap sends ONE command with fixed 10-degree increment
class _OverlayCameraControl extends ConsumerWidget {
  const _OverlayCameraControl();

  static const double _increment = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servoControl = ref.watch(servoControlProvider.notifier);
    final servoState = ref.watch(servoControlProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'CAMERA',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(78),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Up button (tilt up)
              Positioned(
                top: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: _DpadButton(
                    icon: Icons.keyboard_arrow_up,
                    onTap: () => servoControl.adjustTilt(_increment),
                  ),
                ),
              ),
              // Down button (tilt down)
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: _DpadButton(
                    icon: Icons.keyboard_arrow_down,
                    onTap: () => servoControl.adjustTilt(-_increment),
                  ),
                ),
              ),
              // Left button (pan left) - positive increment moves camera left
              Positioned(
                left: -4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _DpadButton(
                    icon: Icons.keyboard_arrow_left,
                    onTap: () => servoControl.adjustPan(_increment),
                  ),
                ),
              ),
              // Right button (pan right) - negative increment moves camera right
              Positioned(
                right: -4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _DpadButton(
                    icon: Icons.keyboard_arrow_right,
                    onTap: () => servoControl.adjustPan(-_increment),
                  ),
                ),
              ),
              // Center indicator showing current position
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${servoState.pan.round()}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// D-pad button for camera control
class _DpadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DpadButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// Coach mode trick buttons overlay for drive screen (landscape)
class _DriveCoachOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachState = ref.watch(coachProvider);
    final isConnected = ref.watch(isRobotOnlineProvider);
    final telemetry = ref.watch(telemetryProvider);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 88,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Detection chip
          if (telemetry.dogDetected)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.getBehaviorColor(telemetry.currentBehavior).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pets, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    AppTheme.getBehaviorDisplayName(telemetry.currentBehavior).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  if (telemetry.confidence != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${(telemetry.confidence! * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          // Trick buttons
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'COACH',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: coachState.watchingFor.map((behavior) {
                    final isHighlighted = coachState.lastRewardBehavior?.toLowerCase() == behavior.toLowerCase();
                    return GestureDetector(
                      onTap: coachState.isActive && isConnected
                          ? () => ref.read(coachProvider.notifier).forceTrick(behavior)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHighlighted
                                ? Colors.green
                                : coachState.isActive && isConnected
                                    ? AppTheme.primary.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.3),
                            width: coachState.isActive && isConnected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          AppTheme.getBehaviorDisplayName(behavior).toUpperCase(),
                          style: TextStyle(
                            color: isHighlighted ? Colors.green : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Active mission banner shown on drive screen
class _ActiveMissionBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(missionsProvider);
    final missionName = missionsState.activeMission?.name ?? 'Mission';
    final stage = missionsState.statusDisplay.isNotEmpty ? missionsState.statusDisplay : missionsState.stageDisplay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              stage != null ? '$missionName — $stage' : missionName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// v1.3: Landscape mode selector — Manual / Coach / Mission
class _LandscapeModeSelector extends ConsumerWidget {
  final RobotMode currentMode;
  final bool isChanging;
  final bool isMissionActive;

  const _LandscapeModeSelector({
    required this.currentMode,
    required this.isChanging,
    required this.isMissionActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeLabel = currentMode.label.toUpperCase();
    final color = _getModeColor(currentMode);

    return PopupMenuButton<RobotMode>(
      onSelected: (mode) {
        if (mode == currentMode) return;
        ref.read(modeStateProvider.notifier).setMode(mode, source: 'landscape_selector');
      },
      offset: const Offset(0, 36),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isChanging ? 0.6 : 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChanging)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(_getModeIcon(currentMode), color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              modeLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) {
        // Landscape options: Manual, Coach, Mission (mission only if active)
        final options = <RobotMode>[
          RobotMode.manual,
          RobotMode.coach,
          if (isMissionActive) RobotMode.mission,
        ];
        return options.map((mode) {
          return PopupMenuItem<RobotMode>(
            value: mode,
            child: Row(
              children: [
                Icon(_getModeIcon(mode), size: 20, color: _getModeColor(mode)),
                const SizedBox(width: 12),
                Text(mode.label),
                if (mode == currentMode) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 20),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Color _getModeColor(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle: return Colors.grey;
      case RobotMode.manual: return Colors.blue;
      case RobotMode.silentGuardian: return Colors.purple;
      case RobotMode.coach: return Colors.orange;
      case RobotMode.mission: return Colors.green;
    }
  }

  IconData _getModeIcon(RobotMode mode) {
    switch (mode) {
      case RobotMode.idle: return Icons.pause_circle_outline;
      case RobotMode.manual: return Icons.gamepad;
      case RobotMode.silentGuardian: return Icons.visibility;
      case RobotMode.coach: return Icons.school;
      case RobotMode.mission: return Icons.flag;
    }
  }
}

/// Overlay action button
class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
