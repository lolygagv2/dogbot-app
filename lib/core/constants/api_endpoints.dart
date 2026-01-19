/// All WIM-Z API endpoint paths
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String health = '/health';
  static const String telemetry = '/telemetry';
  static const String websocket = '/ws';

  // Motor control
  static const String motorSpeed = '/motor/speed';
  static const String motorStop = '/motor/stop';
  static const String motorEmergency = '/motor/emergency';

  // Camera & Servos
  static const String cameraStream = '/camera/stream';
  static const String cameraSnapshot = '/camera/snapshot';
  static const String servoPan = '/servo/pan';
  static const String servoTilt = '/servo/tilt';
  static const String servoCenter = '/servo/center';

  // Treat dispenser
  static const String treatDispense = '/treat/dispense';
  static const String treatCarouselRotate = '/treat/carousel/rotate';

  // LED control
  static const String ledPattern = '/led/pattern';
  static const String ledColor = '/led/color';
  static const String ledOff = '/led/off';

  // Audio
  static const String audioPlay = '/audio/play';
  static const String audioStop = '/audio/stop';
  static const String audioVolume = '/audio/volume';
  static const String audioFiles = '/audio/files';

  // Mode control
  static const String modeGet = '/mode/get';
  static const String modeSet = '/mode/set';

  // Missions
  static const String missions = '/missions';
  static String missionById(String id) => '/missions/$id';
  static String missionStart(String id) => '/missions/$id/start';
  static String missionStop(String id) => '/missions/$id/stop';
  static const String missionActive = '/missions/active';
}

/// LED pattern names
class LedPatterns {
  LedPatterns._();

  static const String breathing = 'breathing';
  static const String rainbow = 'rainbow';
  static const String celebration = 'celebration';
  static const String searching = 'searching';
  static const String alert = 'alert';
  static const String idle = 'idle';

  static const List<String> all = [
    breathing,
    rainbow,
    celebration,
    searching,
    alert,
    idle,
  ];
}

/// Robot operating modes
class RobotModes {
  RobotModes._();

  static const String idle = 'idle';
  static const String guardian = 'guardian';
  static const String training = 'training';
  static const String manual = 'manual';
  static const String docking = 'docking';

  static const List<String> all = [
    idle,
    guardian,
    training,
    manual,
    docking,
  ];
}
