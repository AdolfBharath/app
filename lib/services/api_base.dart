import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

/// Shared base class for all domain API services.
///
/// Methods are intentionally non-underscore so subclasses in separate
/// Dart library files can access them (Dart's `_` is per-library, not per-class).
abstract class ApiServiceBase {
  /// Constructs a full URI from a path fragment, e.g. `/courses`.
  Uri buildUri(String path) => ApiConfig.uri(path);

  /// Builds JSON + Authorization headers with the stored JWT (if any).
  Future<Map<String, String>> buildAuthHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await TokenService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Returns `true` for 2xx responses.
  bool isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  /// Clears the stored JWT and throws [UnauthorizedApiException] on 401.
  void throwIfUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      TokenService.removeToken();
      throw UnauthorizedApiException(
        'Session expired or token invalid. Please log in again.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Extracts the `message` field from a JSON error body, or `null`.
  String? extractErrorMessage(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// Throws a typed [ApiException] for any non-2xx response.
  /// Always throws — declared [Never] so Dart's flow analysis treats it as
  /// a hard exit and suppresses false "body might complete normally" warnings.
  Never throwApiError(http.Response response, String fallback) {
    throwIfUnauthorized(response);
    throw ApiException(
      extractErrorMessage(response) ??
          '$fallback (code ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared exception types
// ---------------------------------------------------------------------------

/// General API error. Contains a user-readable [message] and the HTTP
/// [statusCode] for programmatic handling.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

/// Thrown when the server returns 401. The stored JWT has already been cleared.
/// Callers should navigate the user back to the login screen.
class UnauthorizedApiException extends ApiException {
  UnauthorizedApiException(super.message, {super.statusCode});

  @override
  String toString() => 'UnauthorizedApiException(message: $message)';
}

/// Thrown when `POST /users` returns 409 (duplicate email).
class DuplicateEmailException implements Exception {
  DuplicateEmailException(this.message);

  final String message;

  @override
  String toString() => 'DuplicateEmailException(message: $message)';
}
