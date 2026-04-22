import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_service.dart';

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
      ...?extra,
    };

    if (requiresAuth) {
      final token = await TokenService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ---------------------------------------------------------------------------
  // Response handling
  // ---------------------------------------------------------------------------

  void _checkStatus(http.Response response, String path) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401) {
      // Token is missing / expired — clear it so the UI can redirect to login.
      TokenService.removeToken();
      throw UnauthorizedException(response.statusCode, response.body);
    }

    throw ApiException(response.statusCode, response.body);
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
            headers: await _headers(requiresAuth: requiresAuth),
            body: jsonEncode(body),
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

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    if (kDebugMode) print('[API] PUT $path');

    try {
      final response = await _client
          .put(
            _uri(path),
            headers: await _headers(requiresAuth: requiresAuth),
            body: jsonEncode(body),
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

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
  }) async {
    if (kDebugMode) print('[API] GET $path');

    try {
      final response = await _client
          .get(
            _uri(path, query),
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
    if (kDebugMode) print('[API] GET $path');

    try {
      final response = await _client
          .get(
            _uri(path, query),
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
