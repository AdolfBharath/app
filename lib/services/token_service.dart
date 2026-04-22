import 'package:shared_preferences/shared_preferences.dart';

/// Centralized helper for storing and retrieving the JWT access token.
class TokenService {
  static const String _tokenKey = 'jwt_token';

  /// Persist the JWT token for later authenticated requests.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Retrieve the currently stored JWT token, if any.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  /// Remove any stored JWT token (used on logout).
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
