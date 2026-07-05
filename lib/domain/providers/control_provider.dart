import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import 'connection_mode_provider.dart';
import 'connection_provider.dart';
import 'dog_profiles_provider.dart';
import 'settings_provider.dart';
import 'webrtc_provider.dart';

/// Motor control state
class MotorState {
  final double left;
  final double right;
  final bool isMoving;

  const MotorState({
    this.left = 0.0,
    this.right = 0.0,
    this.isMoving = false,
  });

  MotorState copyWith({double? left, double? right, bool? isMoving}) {
    return MotorState(
      left: left ?? this.left,
      right: right ?? this.right,
      isMoving: isMoving ?? this.isMoving,
    );
  }
}

/// Provider for motor control
final motorControlProvider =
    StateNotifierProvider<MotorControlNotifier, MotorState>((ref) {
  return MotorControlNotifier(ref);
});

/// Motor control notifier - handles joystick input
class MotorControlNotifier extends StateNotifier<MotorState> {
  final Ref _ref;

  // SAFETY deadman subscriptions — see _onMotorLinkLost.
  StreamSubscription<WsConnectionState>? _wsSub;
  ProviderSubscription<WebRTCState>? _webrtcSub;
  WsConnectionState _lastWsState = WsConnectionState.disconnected;

  MotorControlNotifier(this._ref) : super(const MotorState()) {
    // SAFETY deadman. Drive commands ride the WebSocket in local mode and the
    // WebRTC data channel in relay mode. If the ACTIVE motor transport drops
    // while the wheels are commanded to move, we can no longer steer or stop
    // the robot over it — react immediately rather than leaving it running at
    // its last commanded speed. This is defense-in-depth, NOT a substitute for
    // the robot-side command-timeout watchdog (the app cannot stop a robot it
    // can't reach). See .claude/ROBOT_ISSUES_2026-05-30.md (R-SAFETY-1).
    final ws = _ref.read(websocketClientProvider);
    _lastWsState = ws.state;
    _wsSub = ws.stateStream.listen((next) {
      final lost = _lastWsState == WsConnectionState.connected &&
          next != WsConnectionState.connected;
      _lastWsState = next;
      // Local mode drives over the WS, so its loss IS the motor-transport loss.
      if (lost && state.isMoving && _ref.read(isLocalModeProvider)) {
        _onMotorLinkLost('WebSocket');
      }
    });
    _webrtcSub = _ref.listen<WebRTCState>(webrtcStateProvider, (prev, next) {
      final lost =
          prev == WebRTCState.connected && next != WebRTCState.connected;
      // Relay mode drives over the WebRTC data channel.
      if (lost && state.isMoving && !_ref.read(isLocalModeProvider)) {
        _onMotorLinkLost('WebRTC data channel');
      }
    });
  }

  /// SAFETY: the active motor transport dropped mid-drive. Zero our command
  /// state — so the 50 ms joystick ramp re-send (drive_screen.dart) and any
  /// reconnect can't resume the robot at speed — and fire an emergency stop
  /// over whatever transport still survives (in local mode the WS is normally
  /// still up, so the stop actually reaches the robot).
  void _onMotorLinkLost(String which) {
    if (!mounted) return;
    print('MotorControl: ⚠️ SAFETY — $which lost while moving; zero + e-stop');
    state = const MotorState(left: 0, right: 0, isMoving: false);
    emergencyStop();
  }

  /// Set motor speeds. The joystick widget calls this on its 20 Hz ramp tick;
  /// each call goes straight out the active transport (no debounce).
  /// left/right: -1.0 to 1.0
  void setMotorSpeeds(double left, double right) {
    state = MotorState(
      left: left.clamp(-1.0, 1.0),
      right: right.clamp(-1.0, 1.0),
      isMoving: left.abs() > 0.05 || right.abs() > 0.05,
    );
    _sendCommandImmediate();
  }

  void _sendCommandImmediate() {
    if (!_ref.read(connectionProvider).isConnected) return;

    // Positive trim slows the right motor (fixes left drift); negative speeds it up.
    final trim = _ref.read(motorTrimProvider);
    final adjustedRight = (state.right * (1 - trim)).clamp(-1.0, 1.0);

    // SAFETY: in local AP mode drive over the rock-solid WebSocket, NOT the
    // WebRTC data channel (which dies ~100 s in and strands the robot at its
    // last command). Every other control already rides the WS in local mode.
    if (_ref.read(isLocalModeProvider)) {
      _ref
          .read(websocketClientProvider)
          .sendMotorCommand(state.left, adjustedRight);
      return;
    }

    // Relay mode: low-latency WebRTC data channel, falling back to the WS when
    // the channel is closed (safer than the old silent drop).
    final webrtc = _ref.read(webrtcProvider.notifier);
    if (webrtc.isDataChannelOpen) {
      webrtc.sendMotorCommand(state.left, adjustedRight);
    } else {
      _ref
          .read(websocketClientProvider)
          .sendMotorCommand(state.left, adjustedRight);
    }
  }

  /// Emergency stop — zeros state and sends the dedicated stop frame on the
  /// most reliable channel for the current mode.
  void emergencyStop() {
    state = const MotorState(left: 0, right: 0, isMoving: false);

    if (!_ref.read(connectionProvider).isConnected) return;
    final ws = _ref.read(websocketClientProvider);

    // Local mode: the WS is the stable transport; the data channel is the one
    // that fails. Always stop over the WS.
    if (_ref.read(isLocalModeProvider)) {
      ws.sendEmergencyStop();
      return;
    }

    // Relay mode: prefer the low-latency data channel, fall back to the WS.
    final webrtc = _ref.read(webrtcProvider.notifier);
    if (webrtc.isDataChannelOpen) {
      webrtc.sendEmergencyStop();
    } else {
      ws.sendEmergencyStop();
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _webrtcSub?.close();
    super.dispose();
  }
}

/// Servo control state
class ServoState {
  final double pan;
  final double tilt;

  const ServoState({this.pan = 0.0, this.tilt = 0.0});

  ServoState copyWith({double? pan, double? tilt}) {
    return ServoState(
      pan: pan ?? this.pan,
      tilt: tilt ?? this.tilt,
    );
  }
}

/// Provider for servo/camera control
final servoControlProvider =
    StateNotifierProvider<ServoControlNotifier, ServoState>((ref) {
  return ServoControlNotifier(ref);
});

/// Servo control notifier
class ServoControlNotifier extends StateNotifier<ServoState> {
  final Ref _ref;
  Timer? _sendTimer;
  bool _hasPendingCommand = false;
  bool _isDragging = false;  // Track if user is actively dragging

  // Build 104: subscribe to WS state so we can re-assert the app's known
  // servo position whenever we (re)connect. Without this, the robot keeps
  // its persisted position across reboots while the app starts at (0,0),
  // so the first D-pad tap teleports the camera to where the app *thinks*
  // we are — user reported as a "violent snap in the wrong direction" on
  // first tap. Re-asserting on connect makes the app the source of truth.
  StreamSubscription<WsConnectionState>? _wsSub;
  WsConnectionState _lastWsState = WsConnectionState.disconnected;

  ServoControlNotifier(this._ref) : super(const ServoState()) {
    final ws = _ref.read(websocketClientProvider);
    _lastWsState = ws.state;
    _wsSub = ws.stateStream.listen((next) {
      if (next == WsConnectionState.connected &&
          _lastWsState != WsConnectionState.connected) {
        // Fire the current app-side position so the robot snaps to it now
        // (out of the user's way) rather than on the first D-pad tap.
        ws.sendServoCommand(state.pan, state.tilt);
      }
      _lastWsState = next;
    });
  }

  /// Set pan/tilt from control input (only sends while dragging)
  void setPosition(double pan, double tilt) {
    // Ignore near-zero positions (deadzone) - joystick springs back on release
    // The center button uses center() method instead
    const deadzone = 2.0;  // Ignore positions within 2 degrees of center
    if (pan.abs() < deadzone && tilt.abs() < deadzone) {
      return;
    }

    // User is actively dragging
    _isDragging = true;

    // No app-side clamp — each robot has different physical ranges, so the
    // robot is the authority on its own servo limits. Out-of-range values
    // are rejected/clamped robot-side and the app picks up the truth via
    // future servo_state echoes.
    state = ServoState(pan: pan, tilt: tilt);

    _hasPendingCommand = true;
    _ensureSendTimer();
  }

  /// Stop sending commands (joystick released)
  void stopTracking() {
    _isDragging = false;
    _hasPendingCommand = false;
    // Don't send anything on release - servo stays where it was
  }

  /// Adjust pan by delta (D-pad style - immediate send). No app-side clamp;
  /// robot enforces its own physical range.
  void adjustPan(double delta) {
    state = ServoState(pan: state.pan + delta, tilt: state.tilt);
    _sendCommandImmediate();
  }

  /// Adjust tilt by delta (D-pad style - immediate send). No app-side clamp;
  /// robot enforces its own physical range.
  void adjustTilt(double delta) {
    state = ServoState(pan: state.pan, tilt: state.tilt + delta);
    _sendCommandImmediate();
  }

  /// Send command immediately (for D-pad taps)
  void _sendCommandImmediate() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendServoCommand(state.pan, state.tilt);
  }

  /// Center camera (explicit button press)
  void center() {
    state = const ServoState(pan: 0, tilt: 0);

    if (_ref.read(connectionProvider).isConnected) {
      final ws = _ref.read(websocketClientProvider);
      // Center via an explicit servo command (pan=0, tilt=0) — the same 'servo'
      // message the joystick uses, which the local-AP robot handler honors. The
      // dedicated 'servo_center' type isn't handled on the local/AP path, so the
      // button did nothing there. sendServoCommand bypasses the _sendCommand
      // deadzone (that guard lives in _sendCommand, not here), so 0,0 is actually
      // transmitted. Also send servo_center for relay/robot builds that act on it.
      ws.sendServoCommand(0, 0);
      ws.sendServoCenter();
    }
  }

  void _ensureSendTimer() {
    if (_sendTimer != null) return;

    _sendTimer = Timer.periodic(AppConstants.joystickSendInterval, (_) {
      if (_hasPendingCommand && _isDragging) {
        _sendCommand();
        _hasPendingCommand = false;
      }
    });
  }

  void _sendCommand() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendServoCommand(state.pan, state.tilt);
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }
}

/// Provider for treat dispenser actions with debouncing
final treatControlProvider = Provider<TreatControl>((ref) {
  return TreatControl(ref);
});

/// Treat dispenser control with debouncing
class TreatControl {
  final Ref _ref;

  // Debounce — single-tap cooldown (entire multi-dispense session counts
  // as one tap). Mechanical dispenser intra-treat spacing is separate.
  static const _debounceMs = 1000;
  // Time the mechanical dispenser needs between consecutive treats.
  // Going faster causes the carousel to skip; slower wastes user time.
  static const _interTreatMs = 700;
  DateTime? _lastDispense;
  bool _dispensing = false;

  TreatControl(this._ref);

  bool _canExecute(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime).inMilliseconds > _debounceMs;
  }

  /// Dispense N treats (defaults to the selected dog's `treatsPerReward`).
  /// Loops N sends spaced by [_interTreatMs] so the mechanical carousel has
  /// time to rotate between treats. Debounces the whole session as one tap
  /// — back-to-back taps still respect [_debounceMs].
  Future<void> dispense({int? count}) async {
    if (_dispensing) {
      print('TreatControl: dispense() in flight, ignoring');
      return;
    }
    final isConnected = _ref.read(connectionProvider).isConnected;
    print('TreatControl: dispense() — isConnected=$isConnected');
    if (!isConnected) return;
    if (!_canExecute(_lastDispense)) {
      print('TreatControl: dispense() debounced');
      return;
    }

    // Resolve count: explicit arg > selected dog's preference > 1.
    final selectedDog = _ref.read(selectedDogProvider);
    final resolved = (count ?? selectedDog?.treatsPerReward ?? 1).clamp(1, 5);

    _lastDispense = DateTime.now();
    _dispensing = true;
    try {
      final ws = _ref.read(websocketClientProvider);
      for (var i = 0; i < resolved; i++) {
        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: _interTreatMs));
          // Re-check connection mid-loop — dispensing into a dead WS is wasted.
          if (!_ref.read(connectionProvider).isConnected) {
            print('TreatControl: lost connection mid-dispense after ${i}/$resolved');
            return;
          }
        }
        ws.sendTreatCommand();
        print('TreatControl: dispensed ${i + 1}/$resolved');
      }
    } finally {
      _dispensing = false;
    }
  }

  /// Rotate carousel (for refilling)
  void rotateCarousel() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendCarouselRotate();
  }

  /// Set treat counter to a specific count
  void setCount(int count) {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendTreatCounterSet(count);
  }

  /// Reset treat counter to full (44 treats = full carousel)
  static const int fullTreatCount = 44;

  void resetCount() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendTreatCounterSet(fullTreatCount);
  }

  /// Clear treat carousel jam — rotates carousel motor to dislodge stuck treat
  void clearJam() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendCarouselRotate();
  }
}

/// Provider for call dog action
final callDogProvider = Provider<CallDogControl>((ref) {
  return CallDogControl(ref);
});

/// Call dog control
class CallDogControl {
  final Ref _ref;

  CallDogControl(this._ref);

  /// Send call dog command to robot with selected dog info
  void call() {
    final isConnected = _ref.read(connectionProvider).isConnected;
    print('CallDog: call() — isConnected=$isConnected');
    if (!isConnected) return;
    final selectedDog = _ref.read(selectedDogProvider);
    print('CallDog: sending callDog dogId=${selectedDog?.id}, dogName=${selectedDog?.name}');
    _ref.read(websocketClientProvider).sendCallDog(
      dogId: selectedDog?.id,
      dogName: selectedDog?.name,
    );
  }
}

/// Provider for LED control with debouncing
final ledControlProvider = Provider<LedControl>((ref) {
  return LedControl(ref);
});

/// LED control with debouncing
class LedControl {
  final Ref _ref;

  // Debounce for LED pattern changes
  static const _debounceMs = 200;
  DateTime? _lastPattern;

  LedControl(this._ref);

  bool _canExecute(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime).inMilliseconds > _debounceMs;
  }

  /// A-LED: the old guard checked connectionProvider alone, which stays
  /// robotOnline through the WS-downgrade debounce — the send then died in
  /// websocket_client with only a console print, while the UI showed success.
  /// Check the socket too, and trace every drop so "LED didn't fire" is
  /// diagnosable from Settings → Connection Diagnostics.
  bool _canSend(String what) {
    final connected = _ref.read(connectionProvider).isConnected &&
        _ref.read(websocketClientProvider).state == WsConnectionState.connected;
    if (!connected) {
      connTrace('led-drop', '$what not sent — no live connection');
    }
    return connected;
  }

  /// Set LED pattern (debounced). Returns false when the command could not
  /// be sent (no live connection) so the UI can stop claiming success.
  bool setPattern(String pattern) {
    if (!_canSend('setPattern($pattern)')) return false;
    if (!_canExecute(_lastPattern)) {
      print('LedControl: setPattern() debounced');
      return true; // duplicate tap swallowed, not a delivery failure
    }
    _lastPattern = DateTime.now();
    _ref.read(websocketClientProvider).sendLedCommand(pattern);
    return true;
  }

  /// BluLight mood LED on/off. Routed through here (instead of the raw WS
  /// client) so it gets the same guard + drop trace as every other LED path.
  bool setMood(bool on) {
    if (!_canSend('setMood($on)')) return false;
    _ref.read(websocketClientProvider).sendMoodLed(on ? 'on' : 'off');
    return true;
  }

  /// Set LED color
  bool setColor(int r, int g, int b) {
    if (!_canSend('setColor($r,$g,$b)')) return false;
    _ref.read(websocketClientProvider).sendLedColor(r, g, b);
    return true;
  }

  /// Turn off LEDs
  bool off() {
    if (!_canSend('off()')) return false;
    _ref.read(websocketClientProvider).sendLedOff();
    return true;
  }
}

/// Provider for audio control with debouncing
final audioControlProvider = Provider<AudioControl>((ref) {
  return AudioControl(ref);
});

/// Audio control with debouncing to prevent command queue buildup
class AudioControl {
  final Ref _ref;

  // Debounce tracking - prevents rapid-fire commands
  static const _debounceMs = 300;
  DateTime? _lastNext;
  DateTime? _lastPrev;
  DateTime? _lastToggle;

  AudioControl(this._ref);

  bool _canExecute(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime).inMilliseconds > _debounceMs;
  }

  /// Play audio file
  void play(String filename) {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendAudioCommand(filename);
  }

  /// Stop playback
  void stop() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendAudioStop();
  }

  /// Set volume (0-100)
  void setVolume(int level) {
    if (!_ref.read(connectionProvider).isConnected) {
      print('AudioControl: Cannot set volume - not connected');
      return;
    }
    print('AudioControl: Setting volume to $level');
    _ref.read(websocketClientProvider).sendAudioVolume(level);
  }

  /// Play next track (debounced)
  void next() {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (!_canExecute(_lastNext)) {
      print('AudioControl: next() debounced');
      return;
    }
    _lastNext = DateTime.now();
    print('AudioControl: next() sent');
    _ref.read(websocketClientProvider).sendAudioNext();
  }

  /// Play previous track (debounced)
  void prev() {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (!_canExecute(_lastPrev)) {
      print('AudioControl: prev() debounced');
      return;
    }
    _lastPrev = DateTime.now();
    print('AudioControl: prev() sent');
    _ref.read(websocketClientProvider).sendAudioPrev();
  }

  /// Toggle play/pause (debounced)
  void toggle() {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (!_canExecute(_lastToggle)) {
      print('AudioControl: toggle() debounced');
      return;
    }
    _lastToggle = DateTime.now();
    print('AudioControl: toggle() sent');
    _ref.read(websocketClientProvider).sendAudioToggle();
  }
}
