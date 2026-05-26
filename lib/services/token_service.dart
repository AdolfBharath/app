import 'package:shared_preferences/shared_preferences.dart';

/// Centralized helper for storing and retrieving the JWT access token.
class TokenService {
  static const String _tokenKey = 'jwt_token';

  // In-memory cache to allow synchronous checks without awaiting
  // SharedPreferences. This helps decide whether a 401 means "session
  // expired" (we had a token) or simply "unauthorized" when only the
  // publishable key is present.
  static String? _cachedToken;

  /// Persist the JWT token for later authenticated requests.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _cachedToken = token;
  }

  /// Retrieve the currently stored JWT token, if any.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    _cachedToken = token;
    return token;
  }

  /// Remove any stored JWT token (used on logout).
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _cachedToken = null;
  }

  /// Synchronously check whether a token is known to exist (cached).
  /// Returns `true` if a token was saved earlier in this process.
  /// Returns true only if the cached token *looks like* a JWT (has two dots).
  /// This prevents treating simple values (like a user id) as an auth token.
  static bool hasTokenSync() {
    final t = _cachedToken;
    if (t == null || t.isEmpty) return false;
    // A JWT typically has two '.' separators (header.payload.signature).
    return t.split('.').length == 3;
  }
}
