import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import 'connection_provider.dart';

/// Available robot modes
enum RobotMode {
  manual('manual', 'Manual'),
  silentGuardian('silent_guardian', 'Silent Guardian'),
  coach('coach', 'Coach'),
  mission('mission', 'Mission');

  final String value;
  final String label;
  const RobotMode(this.value, this.label);

  static RobotMode fromString(String value) {
    return RobotMode.values.firstWhere(
      (mode) => mode.value == value.toLowerCase(),
      orElse: () => RobotMode.manual,
    );
  }
}

/// Provider for mode control
final modeControlProvider = Provider<ModeControl>((ref) {
  return ModeControl(ref);
});

/// Mode control - sends mode change commands
class ModeControl {
  final Ref _ref;

  ModeControl(this._ref);

  /// Set robot mode
  void setMode(RobotMode mode) {
    if (!_ref.read(connectionProvider).isConnected) return;
    _ref.read(websocketClientProvider).sendModeCommand(mode.value);
  }

  /// Set mode by string value
  void setModeByString(String modeValue) {
    final mode = RobotMode.fromString(modeValue);
    setMode(mode);
  }

  /// Set to manual mode (default on connect)
  void setManualMode() {
    setMode(RobotMode.manual);
  }
}
