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

  /// Check if host is an IP address
  static bool isIpAddress(String host) {
    final ipv4Pattern = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    return ipv4Pattern.hasMatch(host);
  }

  /// Check if host is a valid domain name
  static bool isDomainName(String host) {
    // Simple domain validation - allows localhost, subdomains, TLDs
    final domainPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$');
    return domainPattern.hasMatch(host) || host == 'localhost';
  }

  /// Validate host (IP or domain)
  static bool isValidHost(String host) {
    return isIpAddress(host) || isDomainName(host);
  }

  /// Build full base URL
  /// IP addresses: http:// with port
  /// Domain names: https:// without port (or with port if specified)
  static String baseUrl(String host, [int? port]) {
    final p = port ?? defaultPort;
    if (isIpAddress(host)) {
      // IP addresses use http with port
      return 'http://$host:$p';
    }
    // Domain names use https (port 443 is implicit)
    if (p == 443 || p == 8000) {
      return 'https://$host';
    }
    return 'https://$host:$p';
  }

  /// Build WebSocket URL (without token - add token separately)
  /// IP addresses: ws:// with port, /ws/app path
  /// Domain names: wss://, /ws/app path
  static String wsUrl(String host, [int? port]) {
    final p = port ?? defaultPort;
    if (isIpAddress(host)) {
      // IP addresses use ws with port
      return 'ws://$host:$p/ws/app';
    }
    // Domain names use wss
    if (p == 443 || p == 8000) {
      return 'wss://$host/ws/app';
    }
    return 'wss://$host:$p/ws/app';
  }

  /// Build WebSocket URL with auth token
  static String wsUrlWithToken(String host, String token, [int? port]) {
    return '${wsUrl(host, port)}?token=$token';
  }

  /// Build video stream URL
  static String videoStreamUrl(String host, [int? port]) {
    return '${baseUrl(host, port)}/camera/stream';
  }
}
