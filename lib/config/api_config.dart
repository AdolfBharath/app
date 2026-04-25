import 'package:flutter/foundation.dart';

/// Central place to configure the backend API base URL.
///
/// Strategy:
///  • Windows desktop → `localhost` (avoids LAN-stack semaphore timeout
///    when the backend is also running on the same machine).
///  • All other platforms (Android, iOS, Web) → the LAN IP so that
///    phones and browsers can also reach the backend.
///
/// Override at build time for CI / staging:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.x:5000/api
class ApiConfig {
  /// Your machine's LAN IP — used by phones and other devices on Wi‑Fi.
  /// Update this if your local IP changes.
  static const String _lanIp = '10.20.31.224';

  static String get baseUrl {
    // Highest priority: explicit compile-time override.
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // On Windows desktop the Flutter app and the backend run on the same
    // machine. Using the LAN IP causes the TCP stack to route through the
    // Wi-Fi adapter, which can produce "semaphore timeout" errors on Windows.
    // localhost / 127.0.0.1 is always reliable for same-machine communication.
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost:5000/api';
    }

    // For Android / iOS / Web running on a different device, use the LAN IP.
    return 'http://$_lanIp:5000/api';
  }

  static Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}
