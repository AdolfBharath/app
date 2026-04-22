import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Domain service for support message operations.
class SupportService extends ApiServiceBase {
  SupportService._();
  static final SupportService instance = SupportService._();

  Future<void> sendSupportMessage({required String message}) async {
    final uri = buildUri('/support/messages');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'message': message,
      }),
    );

    if (isSuccess(response)) return;
    throwApiError(response, 'Failed to send support message');
  }
}
