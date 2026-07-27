import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:go_router/go_router.dart';

import '../../../core/services/foreground_session_service.dart';
import '../../../data/models/night_mode_state.dart';
import '../../../domain/providers/coach_provider.dart';
import '../../../domain/providers/connection_provider.dart';
import '../../../domain/providers/control_provider.dart';
import '../../../domain/providers/missions_provider.dart';
import '../../../domain/providers/mode_provider.dart';
import '../../../domain/providers/night_mode_provider.dart';
import '../../../domain/providers/telemetry_provider.dart';
import '../../widgets/night_mode/mode_badge.dart';
import '../../widgets/video/smart_video_view.dart';
import '../../widgets/video/webrtc_video_view.dart' show CameraButton, VideoRecordButton;
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

    // Android: start the foreground service so the live link (WS/WebRTC/two-way
    // audio) survives backgrounding instead of being killed by OEM battery
    // optimizers. Started here while foregrounded so a microphone/data session
    // can legitimately continue into the background. No-op on iOS.
    ForegroundSessionService.start();

    // Build 146: entering the drive screen auto-switches to manual ONLY from
    // idle. Any other robot mode (coach, SG, mission) is left untouched — the
    // robot brief 2026-07-26 captured navigation-triggered set_mode sends
    // killing coach mode in local sessions (SG was stomped by the old
    // else-branch too). The drive screen is a viewer for non-manual modes;
    // the user switches explicitly via the mode selector.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modeState = ref.read(modeStateProvider);
      final hasMission = ref.read(missionsProvider).hasActiveMission;
      if (modeState.isMissionActive || modeState.isModeLocked || hasMission) {
        print('DriveScreen: Mission active (${modeState.activeMissionName ?? 'starting'}), keeping mission mode');
      } else if (modeState.currentMode == RobotMode.idle &&
          modeState.pendingMode == null) {
        // Store current portrait mode before entering landscape
        ref.read(modeStateProvider.notifier).storePortraitMode();
        _ensureManualMode();
      } else {
        print('DriveScreen: Robot in ${modeState.currentMode.value} '
            '(pending=${modeState.pendingMode?.value}) — not touching mode');
      }
    });
  }

  @override
  void dispose() {
    // Build 113: send an explicit motor stop when leaving the drive screen so
    // the robot halts instantly instead of waiting out its 500ms watchdog.
    // (Build 38 removed the mode-control command here; a motor zero is a
    // different, safe thing to send.)
    ref.read(motorControlProvider.notifier).emergencyStop();
    // Build 38: Removed sendManualControlInactive() - no commands on screen dispose
    // Allow screen to sleep again
    WakelockPlus.disable();
    print('DriveScreen: Wakelock disabled');
    // Android: tear down the foreground service — the live session is over.
    ForegroundSessionService.stop();
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

  /// Mode/mission cleanup that must run whether the user leaves via the AppBar
  /// back button OR the Android hardware/gesture back. Without this routed
  /// through PopScope, a hardware back on Android would pop the route directly
  /// and skip stopping the mission / restoring portrait mode. (The motor
  /// emergency-stop still happens in dispose(), so this is mode state only.)
  void _handleExitCleanup() {
    final modeState = ref.read(modeStateProvider);
    if (modeState.isMissionActive || modeState.isModeLocked) {
      // Mission active — user is explicitly abandoning it via back:
      // stop it and exit to idle
      ref.read(missionsProvider.notifier).stopMission();
      ref.read(modeStateProvider.notifier).setMode(
            RobotMode.idle,
            source: 'mission_end',
          );
    } else if (modeState.currentMode == RobotMode.manual) {
      // Build 146: restore ONLY from manual — the mode this screen itself
      // auto-entered (or the user picked here). Any other mode (coach, SG,
      // idle) is the robot's business; sending a restore for it was the
      // navigation-triggered set_mode class the robot brief forbids.
      ref.read(modeStateProvider.notifier).restorePortraitMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final motorControl = ref.watch(motorControlProvider.notifier);
    final motorState = ref.watch(motorControlProvider);
    final modeState = ref.watch(modeStateProvider);

    // Check if we're ready to drive (in manual mode and not pending)
    // Build 56: Also check missionsProvider for optimistic mission state (before robot confirms)
    final missionsState = ref.watch(missionsProvider);
    final isMissionActive = modeState.isMissionActive || modeState.currentMode == RobotMode.mission || missionsState.hasActiveMission;
    // Controls are ready if in manual mode (confirmed), or mission/coach active,
    // or in idle mode (Pi may not have confirmed manual yet — don't block buttons)
    final isReady = (modeState.currentMode == RobotMode.manual &&
        modeState.pendingMode == null) || isMissionActive ||
        modeState.currentMode == RobotMode.coach ||
        modeState.currentMode == RobotMode.idle;

    // Clear mode change request flag when confirmed
    if (_modeChangeRequested && isReady) {
      _modeChangeRequested = false;
    }

    final nightState = ref.watch(nightModeProvider);
    final isNightActive = nightState?.currentMode == DayNight.night;

    return PopScope(
      // Intercept Android hardware/gesture back so it runs the same mission/mode
      // cleanup as the AppBar back button instead of popping the route raw.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExitCleanup();
        if (context.mounted) context.pop();
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            _handleExitCleanup();
            context.pop();
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
          // Full-screen video background. showOverlayButtons:false because
          // the drive screen already crowds the bottom-left with the motor
          // joystick — let the parent place camera/record at top-right
          // instead so they don't sit under the joystick (Build 104).
          const SmartVideoView(showOverlayButtons: false),

          // Build 100: Night-mode chrome — thin cool-tone border framing the
          // video. Pointer-transparent so it never blocks controls. The pixels
          // of the IR feed are intentionally left untouched per nightvision.md.
          if (isNightActive)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.behaviorLying.withOpacity(0.55),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

          // Build 100: Mode badge — top-right, below the existing status row.
          // Display-only; override control lives in Settings → Night Vision.
          Positioned(
            top: MediaQuery.of(context).padding.top + 96,
            right: 16,
            child: const ModeBadge(),
          ),

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
                // v1.3: Landscape mode selector (manual/coach/mission).
                // The old conditional detection chip that lived to the right
                // of this selector is gone — it made the whole status row
                // (and the coach trick buttons below) jump on every
                // detection. Dog presence is now the tiny paw next to the
                // LAN/WAN badge (_DogDetectedPaw).
                _LandscapeModeSelector(
                  currentMode: modeState.currentMode,
                  isChanging: modeState.isSwitching,
                  isMissionActive: isMissionActive,
                ),
              ],
            ),
          ),

          // Active mission banner (compact, left-pinned)
          if (isMissionActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 88,
              left: 16,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Center controls - treat, center, PTT mic
                    final centerControls = Column(
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
                    );

                    // A-PORTRAIT: the single row needs ~536px (148px joystick
                    // + ~192px center cluster + 148px camera D-pad + gaps);
                    // portrait phones are 360–430px, which used to clip the
                    // camera D-pad off the right edge. Phones are mounted
                    // fixed-portrait, so reflow to two tiers instead of
                    // demanding rotation: center cluster on top, joystick and
                    // camera D-pad side by side below (296px — fits any phone).
                    if (constraints.maxWidth < 536) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          centerControls,
                          const SizedBox(height: 16),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _MotorJoystick(),
                              _OverlayCameraControl(),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Drive virtual analog joystick (left)
                        const _MotorJoystick(),
                        centerControls,
                        // Camera joystick (right)
                        const _OverlayCameraControl(),
                      ],
                    );
                  },
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

          // WebRTC ICE path diagnostic badge — moved out of the joystick zone
          // (Build 104). Sits below the audio mute toggle on the top-left.
          // The tiny dog-detected paw sits at the END of this row so its
          // appearance never shifts anything else on screen.
          Positioned(
            top: MediaQuery.of(context).padding.top + 96,
            left: 16,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IcePathBadge(),
                SizedBox(width: 6),
                _DogDetectedPaw(),
              ],
            ),
          ),

          // Camera + video-record buttons — placed at top-right beneath the
          // mode badge so they don't overlap the bottom joystick row
          // (Build 104). Same widgets that ride inside WebRTCVideoView when
          // showOverlayButtons:true.
          Positioned(
            top: MediaQuery.of(context).padding.top + 140,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CameraButton(),
                const SizedBox(height: 8),
                VideoRecordButton(),
              ],
            ),
          ),

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

/// Build 94: virtual analog joystick → arcade-mixed motor control.
///
/// Stick (x, y) ∈ [-1, 1]² with y inverted so forward = +y.
/// A 10% radial deadzone suppresses idle drift; magnitudes above the
/// deadzone are linearly remapped to [0, 1] so there is no step at the
/// boundary. Arcade mix: left = y + x, right = y - x (clamped to ±1).
/// A 50 ms ticker ramps current → target at 1/[_rampMs] per ms, giving an
/// approximately 200 ms approach time. The ticker keeps running for one
/// full ramp after release so the stop is smooth rather than jolting.
class _MotorJoystick extends ConsumerStatefulWidget {
  const _MotorJoystick();

  @override
  ConsumerState<_MotorJoystick> createState() => _MotorJoystickState();
}

class _MotorJoystickState extends ConsumerState<_MotorJoystick> {
  static const double _deadzone = 0.10;
  static const int _rampMs = 200;
  static const Duration _tick = Duration(milliseconds: 50);

  Timer? _rampTimer;
  double _targetLeft = 0.0;
  double _targetRight = 0.0;
  double _currentLeft = 0.0;
  double _currentRight = 0.0;
  bool _stickHeld = false;

  @override
  void dispose() {
    _rampTimer?.cancel();
    super.dispose();
  }

  void _onStick(StickDragDetails details) {
    final rawX = details.x;
    final rawY = -details.y; // screen-coords → forward-positive
    final mag = math.sqrt(rawX * rawX + rawY * rawY);

    double x = 0.0;
    double y = 0.0;
    if (mag > _deadzone) {
      // Linear remap [_deadzone, 1] → [0, 1], scale per-axis to preserve angle.
      final scale = ((mag - _deadzone) / (1.0 - _deadzone)).clamp(0.0, 1.0) / mag;
      x = rawX * scale;
      y = rawY * scale;
    }

    _targetLeft = (y + x).clamp(-1.0, 1.0);
    _targetRight = (y - x).clamp(-1.0, 1.0);
    _stickHeld = _targetLeft != 0.0 || _targetRight != 0.0;

    _ensureRamp();
  }

  void _onStickReleased() {
    _stickHeld = false;
    _targetLeft = 0.0;
    _targetRight = 0.0;
    _ensureRamp();
  }

  void _ensureRamp() {
    if (_rampTimer != null) return;
    _rampTimer = Timer.periodic(_tick, (_) => _onRampTick());
  }

  void _onRampTick() {
    const stepPerTick = 1.0 / (_rampMs / 50.0); // 50 ms tick over 200 ms ramp = 0.25
    _currentLeft = _approach(_currentLeft, _targetLeft, stepPerTick);
    _currentRight = _approach(_currentRight, _targetRight, stepPerTick);

    ref
        .read(motorControlProvider.notifier)
        .setMotorSpeeds(_currentLeft, _currentRight);

    if (!_stickHeld && _currentLeft == 0.0 && _currentRight == 0.0) {
      _rampTimer?.cancel();
      _rampTimer = null;
    }
  }

  static double _approach(double current, double target, double step) {
    final diff = target - current;
    if (diff.abs() <= step) return target;
    return current + (diff.isNegative ? -step : step);
  }

  void _emergencyStop() {
    _rampTimer?.cancel();
    _rampTimer = null;
    _targetLeft = _targetRight = 0.0;
    _currentLeft = _currentRight = 0.0;
    _stickHeld = false;
    ref.read(motorControlProvider.notifier).emergencyStop();
  }

  @override
  Widget build(BuildContext context) {
    final motorState = ref.watch(motorControlProvider);
    // Display speed = the larger-magnitude wheel, so pure turns still show a value.
    final mag = math.max(_currentLeft.abs(), _currentRight.abs());
    final speedPercent = (mag * 100).round();

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
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 148,
              height: 148,
              child: Joystick(
                mode: JoystickMode.all,
                period: _tick,
                listener: _onStick,
                onStickDragEnd: _onStickReleased,
              ),
            ),
            // Emergency stop / speed readout pinned to the top-right of the base.
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: _emergencyStop,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: motorState.isMoving
                        ? Colors.red.withOpacity(0.85)
                        : AppTheme.primary.withOpacity(0.5),
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
                        : const Icon(Icons.stop, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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

    // No detection chip here anymore — it pushed the trick buttons down on
    // every detection. Dog presence lives in _DogDetectedPaw (top-left).
    return Positioned(
      top: MediaQuery.of(context).padding.top + 88,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
                    // Reward flash (green, 3s) wins over the active-trick
                    // highlight (blue) — tapping any trick force-switches the
                    // session to it and moves the blue highlight.
                    final isRewarded = coachState.lastRewardBehavior?.toLowerCase() == behavior.toLowerCase();
                    final isActiveTrick = coachState.isActiveTrick(behavior);
                    return GestureDetector(
                      onTap: coachState.isActive && isConnected
                          ? () {
                              final ok = ref
                                  .read(coachProvider.notifier)
                                  .forceTrick(behavior);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Select a dog or wait for the camera to identify one.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isRewarded
                              ? Colors.green.withOpacity(0.3)
                              : isActiveTrick
                                  ? AppTheme.primary.withOpacity(0.35)
                                  : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRewarded
                                ? Colors.green
                                : isActiveTrick
                                    ? AppTheme.primary
                                    : coachState.isActive && isConnected
                                        ? AppTheme.primary.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.3),
                            width: isActiveTrick || (coachState.isActive && isConnected) ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          AppTheme.getBehaviorDisplayName(behavior).toUpperCase(),
                          style: TextStyle(
                            color: isRewarded
                                ? Colors.green
                                : isActiveTrick
                                    ? AppTheme.primary
                                    : Colors.white,
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

/// Active mission banner shown on drive screen — includes stop button
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
          const SizedBox(width: 8),
          // Stop mission button — exits mission and returns to idle
          GestureDetector(
            onTap: () {
              ref.read(missionsProvider.notifier).stopMission();
              ref.read(modeStateProvider.notifier).setMode(
                RobotMode.idle,
                source: 'mission_end',
              );
              context.pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'STOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
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

/// Minimal dog-detected indicator: a single small paw print next to the
/// LAN/WAN badge, tinted by the current behavior. Replaces the two old
/// detection chips (status row + coach overlay) that reflowed the layout —
/// and made the trick buttons jump — every time a dog was detected.
class _DogDetectedPaw extends ConsumerWidget {
  const _DogDetectedPaw();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider);
    if (!telemetry.dogDetected) return const SizedBox.shrink();

    return Icon(
      Icons.pets,
      size: 14,
      color: AppTheme.getBehaviorColor(telemetry.currentBehavior),
      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
    );
  }
}

/// WebRTC connection type badge — reads from robot telemetry
/// "LAN" = direct P2P (same WiFi), "WAN" = TURN relay
class _IcePathBadge extends ConsumerWidget {
  const _IcePathBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionType = ref.watch(telemetryProvider).connectionType;

    // Only show when robot reports connection type
    if (connectionType == null) return const SizedBox.shrink();

    final Color badgeColor;
    final IconData badgeIcon;
    if (connectionType == 'LAN') {
      badgeColor = Colors.green;
      badgeIcon = Icons.wifi;
    } else {
      // WAN / TURN relay
      badgeColor = Colors.orange;
      badgeIcon = Icons.cloud;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 12),
          const SizedBox(width: 4),
          Text(
            connectionType,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
