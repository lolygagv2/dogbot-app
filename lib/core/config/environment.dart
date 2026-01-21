/// Environment configuration for dev/prod switching
enum Environment { dev, prod }

class AppConfig {
  /// Current environment - set to dev for local robot testing
  /// Production: https://api.wimzai.com, wss://api.wimzai.com/ws/app
  /// Dev: http://<local-ip>:8000, ws://<local-ip>:8000/ws
  static Environment env = Environment.prod;

  /// Default server host based on environment
  static String get defaultHost {
    switch (env) {
      case Environment.dev:
        return '192.168.1.50'; // Local WIM-Z IP - change to your robot's IP
      case Environment.prod:
        return 'api.wimzai.com'; // Production cloud endpoint
    }
  }

  /// Default server port
  static int get defaultPort => 8000;

  /// WebSocket scheme (ws for dev, wss for prod)
  static String get wsScheme => env == Environment.prod ? 'wss' : 'ws';

  /// HTTP scheme (http for dev, https for prod)
  static String get httpScheme => env == Environment.prod ? 'https' : 'http';

  /// Build full base URL
  static String baseUrl(String host, [int? port]) {
    final p = port ?? defaultPort;
    if (env == Environment.prod) {
      return '$httpScheme://$host';
    }
    return '$httpScheme://$host:$p';
  }

  /// Build WebSocket URL
  static String wsUrl(String host, [int? port]) {
    final p = port ?? defaultPort;
    if (env == Environment.prod) {
      return '$wsScheme://$host/ws/app';
    }
    return '$wsScheme://$host:$p/ws';
  }

  /// Build video stream URL
  static String videoStreamUrl(String host, [int? port]) {
    return '${baseUrl(host, port)}/camera/stream';
  }
}
