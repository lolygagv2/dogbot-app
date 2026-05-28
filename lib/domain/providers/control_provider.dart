import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/websocket_client.dart';
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

  MotorControlNotifier(this._ref) : super(const MotorState());

  /// Set motor speeds. The joystick widget calls this on its 20 Hz ramp tick;
  /// each call goes straight out the WebRTC data channel (no debounce).
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

    final webrtc = _ref.read(webrtcProvider.notifier);
    if (webrtc.isDataChannelOpen) {
      webrtc.sendMotorCommand(state.left, adjustedRight);
    }
  }

  /// Emergency stop — zeros state and sends the dedicated stop frame on the
  /// lowest-latency channel available.
  void emergencyStop() {
    state = const MotorState(left: 0, right: 0, isMoving: false);

    if (_ref.read(connectionProvider).isConnected) {
      final webrtc = _ref.read(webrtcProvider.notifier);
      if (webrtc.isDataChannelOpen) {
        webrtc.sendEmergencyStop();
      } else {
        _ref.read(websocketClientProvider).sendEmergencyStop();
      }
    }
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

    state = ServoState(
      pan: pan.clamp(-AppConstants.maxPanAngle, AppConstants.maxPanAngle),
      tilt: tilt.clamp(-AppConstants.maxTiltAngle, AppConstants.maxTiltAngle),
    );

    _hasPendingCommand = true;
    _ensureSendTimer();
  }

  /// Stop sending commands (joystick released)
  void stopTracking() {
    _isDragging = false;
    _hasPendingCommand = false;
    // Don't send anything on release - servo stays where it was
  }

  /// Adjust pan by delta (D-pad style - immediate send)
  void adjustPan(double delta) {
    final newPan = (state.pan + delta).clamp(-AppConstants.maxPanAngle, AppConstants.maxPanAngle);
    state = ServoState(pan: newPan, tilt: state.tilt);
    _sendCommandImmediate();
  }

  /// Adjust tilt by delta (D-pad style - immediate send)
  void adjustTilt(double delta) {
    final newTilt = (state.tilt + delta).clamp(-AppConstants.maxTiltAngle, AppConstants.maxTiltAngle);
    state = ServoState(pan: state.pan, tilt: newTilt);
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
      _ref.read(websocketClientProvider).sendServoCenter();
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

  /// Set LED pattern (debounced)
  void setPattern(String pattern) {
    if (!_ref.read(connectionProvider).isConnected) return;
    if (!_canExecute(_lastPattern)) {
      print('LedControl: setPattern() debounced');
      return;
    }
    _lastPattern = DateTime.now();
    _ref.read(websocketClientProvider).sendLedCommand(pattern);
  }

  /// Set LED color
  void setColor(int r, int g, int b) {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendLedColor(r, g, b);
  }

  /// Turn off LEDs
  void off() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendLedOff();
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
