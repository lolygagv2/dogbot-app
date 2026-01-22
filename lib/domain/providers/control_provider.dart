import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/websocket_client.dart';
import 'connection_provider.dart';
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
  Timer? _sendTimer;
  bool _hasPendingCommand = false;

  MotorControlNotifier(this._ref) : super(const MotorState());

  /// Set motor speeds from joystick input
  /// x: left/right (-1 to 1), y: forward/backward (-1 to 1)
  void setFromJoystick(double x, double y) {
    // Convert to differential drive
    final left = (y + x).clamp(-1.0, 1.0);
    final right = (y - x).clamp(-1.0, 1.0);

    state = MotorState(
      left: left,
      right: right,
      isMoving: left.abs() > 0.05 || right.abs() > 0.05,
    );

    _hasPendingCommand = true;
    _ensureSendTimer();
  }

  /// Stop motors immediately
  void stop() {
    state = const MotorState(left: 0, right: 0, isMoving: false);
    _sendCommand();
  }

  /// Emergency stop
  void emergencyStop() {
    state = const MotorState(left: 0, right: 0, isMoving: false);
    _sendTimer?.cancel();

    if (_ref.read(connectionProvider).isConnected) {
      // Send via WebRTC for lowest latency, fallback to WebSocket
      final webrtc = _ref.read(webrtcProvider.notifier);
      if (webrtc.isDataChannelOpen) {
        webrtc.sendEmergencyStop();
      } else {
        _ref.read(websocketClientProvider).sendEmergencyStop();
      }
    }
  }

  void _ensureSendTimer() {
    if (_sendTimer != null) return;

    // Send commands at fixed rate (20Hz)
    _sendTimer = Timer.periodic(AppConstants.joystickSendInterval, (_) {
      if (_hasPendingCommand) {
        _sendCommand();
        _hasPendingCommand = false;
      }
    });
  }

  void _sendCommand() {
    if (!_ref.read(connectionProvider).isConnected) return;

    // Use WebRTC data channel for lowest latency (direct to robot)
    final webrtc = _ref.read(webrtcProvider.notifier);
    if (webrtc.isDataChannelOpen) {
      webrtc.sendMotorCommand(state.left, state.right);
    }
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
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

  ServoControlNotifier(this._ref) : super(const ServoState());

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

  /// Adjust pan by delta
  void adjustPan(double delta) {
    setPosition(state.pan + delta, state.tilt);
  }

  /// Adjust tilt by delta
  void adjustTilt(double delta) {
    setPosition(state.pan, state.tilt + delta);
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
    super.dispose();
  }
}

/// Provider for treat dispenser actions
final treatControlProvider = Provider<TreatControl>((ref) {
  return TreatControl(ref);
});

/// Treat dispenser control
class TreatControl {
  final Ref _ref;

  TreatControl(this._ref);

  /// Dispense a treat
  Future<void> dispense() async {
    if (!_ref.read(connectionProvider).isConnected) return;

    // Use WebSocket for speed
    _ref.read(websocketClientProvider).sendTreatCommand();
  }

  /// Rotate carousel (for refilling)
  void rotateCarousel() {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendCarouselRotate();
  }
}

/// Provider for LED control
final ledControlProvider = Provider<LedControl>((ref) {
  return LedControl(ref);
});

/// LED control
class LedControl {
  final Ref _ref;

  LedControl(this._ref);

  /// Set LED pattern
  void setPattern(String pattern) {
    if (!_ref.read(connectionProvider).isConnected) return;
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

/// Provider for audio control
final audioControlProvider = Provider<AudioControl>((ref) {
  return AudioControl(ref);
});

/// Audio control
class AudioControl {
  final Ref _ref;

  AudioControl(this._ref);

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

  /// Set volume
  void setVolume(int level) {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendAudioVolume(level);
  }
}
