/// Application-wide constants
class AppConstants {
  AppConstants._();

  // Network timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration websocketReconnectDelay = Duration(seconds: 3);
  static const Duration websocketPingInterval = Duration(seconds: 30);

  // Control rates
  static const Duration joystickSendInterval = Duration(milliseconds: 50); // 20Hz
  static const Duration telemetryRefreshInterval = Duration(seconds: 2);

  // Default server config
  static const int defaultPort = 8000;
  static const String defaultHost = '192.168.1.50';

  // UI constants
  static const double joystickSize = 200.0;
  static const double panTiltControlSize = 150.0;
  static const double videoAspectRatio = 16 / 9;

  // Limits
  static const double maxMotorSpeed = 1.0;
  static const double maxPanAngle = 90.0;
  static const double maxTiltAngle = 45.0;
  static const int maxVolumeLevel = 100;

  // Storage keys
  static const String keyServerHost = 'server_host';
  static const String keyServerPort = 'server_port';
  static const String keyLastConnected = 'last_connected';
  static const String keyDarkMode = 'dark_mode';
  static const String keyDeviceId = 'paired_device_id';

  // Default device
  static const String defaultDeviceId = 'wimz_robot_01';
}
