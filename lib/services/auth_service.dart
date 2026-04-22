import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Handles authentication-related API calls that require an active session.
class AuthService extends ApiServiceBase {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Change the current admin user's password.
  ///
  /// Calls `PUT /api/users/current`.
  Future<bool> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = buildUri('/users/current');
    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to change password');
  }
}
