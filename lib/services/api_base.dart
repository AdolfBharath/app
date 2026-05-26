import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/supabase_config.dart';
import 'local_cache_service.dart';
import 'token_service.dart';

/// Shared base class for all domain API services.
///
/// Methods are intentionally non-underscore so subclasses in separate
/// Dart library files can access them (Dart's `_` is per-library, not per-class).
abstract class ApiServiceBase {
  int get defaultPageSize => 20;
  int get expandedPageSize => 30;

  /// Constructs a full URI from a path fragment, e.g. `/courses`.
  Uri buildUri(String path) => ApiConfig.uri(path);

  /// Builds JSON + Supabase Authorization and API Key headers
  Future<Map<String, String>> buildAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      // Supabase REST requires the `apikey` header and an Authorization bearer
      // token. Provide both so requests are accepted by Supabase projects.
      // Provide both `x-app-key` (used by the Functions proxy) and `apikey`/
      // `Authorization` (used by PostgREST/Supabase REST) so either routing
      // strategy accepts the request.
      'x-app-key': SupabaseConfig.useFunctionProxy
          ? SupabaseConfig.appKey
          : SupabaseConfig.apiKey,
      'apikey': SupabaseConfig.apiKey,
      'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
      'Prefer': 'return=representation',
    };
    return headers;
  }

  /// Returns `true` for 2xx responses.
  bool isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  /// Clears the stored JWT and throws [UnauthorizedApiException] on 401.
  void throwIfUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      if (TokenService.hasTokenSync()) {
        TokenService.removeToken();
        throw UnauthorizedApiException(
          'Session expired or token invalid. Please log in again.',
          statusCode: response.statusCode,
        );
      }
      throw ApiException('Unauthorized request (requires authentication)', statusCode: response.statusCode);
    }
  }

  /// Extracts the `message` field from a JSON error body, or `null`.
  String? extractErrorMessage(http.Response response) {
    try {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code']?.toString();
        final hint = decoded['hint']?.toString() ?? '';
        if ((response.statusCode == 401 || response.statusCode == 403) &&
            code == '42501' &&
            !SupabaseConfig.useFunctionProxy &&
            SupabaseConfig.adminProxyUrl.isEmpty) {
          return 'Supabase rejected this write with the public key. Run the app with SUPABASE_APP_KEY for the Edge Function proxy, or ADMIN_PROXY_URL for the Node admin proxy.';
        }
        if (hint.isNotEmpty) return hint;
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

  /// Helper to fetch a list of JSON objects from a path.
  Future<List<Map<String, dynamic>>> getJsonList(String path) async {
    final uri = buildUri(path);
    final response = await http
        .get(uri, headers: await buildAuthHeaders())
        .timeout(const Duration(seconds: 12));

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    }

    throwApiError(response, 'Failed to fetch list from $path');
  }

  Future<List<Map<String, dynamic>>> getCachedJsonList(
    String path, {
    Duration ttl = const Duration(minutes: 5),
    bool disk = false,
  }) {
    return LocalCacheService.instance.remember<List<Map<String, dynamic>>>(
      path,
      () => getJsonList(path),
      ttl: ttl,
      disk: disk,
      fromJson: (decoded) {
        if (decoded is List) {
          return decoded
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(growable: false);
        }
        return <Map<String, dynamic>>[];
      },
    );
  }

  void invalidateCache(String prefix) {
    LocalCacheService.instance.invalidatePrefix(prefix);
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
