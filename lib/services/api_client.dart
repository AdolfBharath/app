import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_service.dart';
import '../utils/supabase_config.dart';

/// A thin HTTP client that:
///  1. Prefixes all paths with the configured base URL.
///  2. Automatically attaches `Authorization: Bearer <token>` on every
///     request when a JWT is stored in [TokenService].
///  3. Throws [ApiException] on non-2xx responses and
///     [UnauthorizedException] (a subclass) on 401 so callers can
///     redirect to the login screen.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client() {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[API] Base URL: $baseUrl');
    }
  }

  final http.Client _client;

  static String get baseUrl => ApiConfig.baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    return ApiConfig.uri(path, queryParameters);
  }

  String _optimizeReadPath(String path) {
    if (!path.startsWith('/')) return path;
    if (path.contains('select=') || path.contains('/storage/')) return path;
    var next = path;
    String separator() => next.contains('?') ? '&' : '?';
    if (next.startsWith('/users')) {
      next =
          '$next${separator()}select=id,name,email,role,username,admin_no,phone,batch_id,profile_pic,expertise,coins,streak_count,last_active_date,weekly_logins,created_at';
    } else if (next.startsWith('/notifications')) {
      next =
          '$next${separator()}select=id,title,message,type,target_group,read,created_at,sender_id';
    }
    if (!next.contains('limit=') &&
        (next.startsWith('/users') || next.startsWith('/notifications'))) {
      next = '$next${separator()}limit=20';
    }
    return next;
  }

  // ---------------------------------------------------------------------------
  // Auth header helper
  // ---------------------------------------------------------------------------

  /// Builds default headers, merging any [extra] headers and the
  /// stored JWT (if present) into `Authorization: Bearer <token>`.
  Future<Map<String, String>> _headers({
    Map<String, String>? extra,
    bool requiresAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-app-key': SupabaseConfig.useFunctionProxy
          ? SupabaseConfig.appKey
          : SupabaseConfig.apiKey,
      'apikey': SupabaseConfig.apiKey,
      ...?extra,
    };

    // Prefer a stored JWT when available for authenticated requests.
    // If `requiresAuth` is false, keep using the public/publishable API key.
    if (requiresAuth) {
      final token = await TokenService.getToken();
      // Only attach the token if it *looks like* a JWT. Some callers
      // historically saved non-JWT values (user ids) which should not be
      // sent as Authorization; fall back to the publishable key instead.
      if (token != null && token.isNotEmpty && token.split('.').length == 3) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        headers['Authorization'] = 'Bearer ${SupabaseConfig.apiKey}';
      }
    } else {
      headers['Authorization'] = 'Bearer ${SupabaseConfig.apiKey}';
    }
    if (kDebugMode) {
      // Mask sensitive values before logging to avoid leaking keys in debug output.
      final masked = Map<String, String>.from(headers);
      if (masked.containsKey('apikey')) masked['apikey'] = '***';
      if (masked.containsKey('x-app-key')) masked['x-app-key'] = '***';
      if (masked.containsKey('Authorization')) masked['Authorization'] = 'Bearer ***';
      // ignore: avoid_print
      print('[API] Headers: $masked');
    }

    return headers;
  }

  // ---------------------------------------------------------------------------
  // Response handling
  // ---------------------------------------------------------------------------

  void _checkStatus(http.Response response, String path) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String body = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['code']?.toString() == '42501' &&
          (response.statusCode == 401 || response.statusCode == 403) &&
          !SupabaseConfig.useFunctionProxy &&
          SupabaseConfig.adminProxyUrl.isEmpty) {
        body =
            'Supabase rejected this write with the public key. Run the app with SUPABASE_APP_KEY for the Edge Function proxy, or ADMIN_PROXY_URL for the Node admin proxy.';
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      // Only treat 401 as "session expired" if we actually had a token.
      if (TokenService.hasTokenSync()) {
        TokenService.removeToken();
        throw UnauthorizedException(response.statusCode, body);
      }
      // Otherwise, surface a neutral API error so the UI doesn't show a
      // misleading "session expired" banner when the publishable key is used.
      throw ApiException(response.statusCode, body);
    }

    throw ApiException(response.statusCode, body);
  }

  // ---------------------------------------------------------------------------
  // HTTP verbs
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    if (kDebugMode) print('[API] POST $path');

    try {
      final response = await _client
          .post(
            _uri(path),
            headers: await _headers(
              requiresAuth: requiresAuth,
              extra: {'Prefer': 'return=representation'},
            ),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout — backend not responding'),
          );

      if (kDebugMode) print('[API] → ${response.statusCode}');
      _checkStatus(response, path);

      if (response.body.trim().isEmpty) return {};
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      } else if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('[API] Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    if (kDebugMode) print('[API] PATCH $path');

    try {
      final response = await _client
          .patch(
            _uri(path),
            headers: await _headers(
              requiresAuth: requiresAuth,
              extra: {'Prefer': 'return=representation'},
            ),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout — backend not responding'),
          );

      if (kDebugMode) print('[API] → ${response.statusCode}');
      _checkStatus(response, path);

      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      } else if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('[API] Error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
  }) async {
    final optimizedPath = query == null ? _optimizeReadPath(path) : path;
    if (kDebugMode) print('[API] GET $path');

    try {
      final response = await _client
          .get(
            _uri(optimizedPath, query),
            headers: await _headers(requiresAuth: requiresAuth),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout — backend not responding'),
          );

      if (kDebugMode) print('[API] → ${response.statusCode}');
      _checkStatus(response, path);
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      if (kDebugMode) print('[API] Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getJsonObject(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
  }) async {
    final optimizedPath = query == null ? _optimizeReadPath(path) : path;
    if (kDebugMode) print('[API] GET $path');

    try {
      final response = await _client
          .get(
            _uri(optimizedPath, query),
            headers: await _headers(requiresAuth: requiresAuth),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout — backend not responding'),
          );

      if (kDebugMode) print('[API] → ${response.statusCode}');
      _checkStatus(response, path);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('[API] Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool requiresAuth = true,
  }) async {
    if (kDebugMode) print('[API] DELETE $path');

    try {
      final response = await _client
          .delete(
            _uri(path),
            headers: await _headers(requiresAuth: requiresAuth),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout — backend not responding'),
          );

      if (kDebugMode) print('[API] → ${response.statusCode}');
      _checkStatus(response, path);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('[API] Error: $e');
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}

/// Thrown when the server returns 401. The token has been cleared by
/// [ApiClient] before throwing so the caller can navigate to login.
class UnauthorizedException extends ApiException {
  UnauthorizedException(super.statusCode, super.body);

  @override
  String toString() => 'UnauthorizedException(statusCode: $statusCode)';
}
