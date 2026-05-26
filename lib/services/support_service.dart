import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Domain service for support message operations.
class SupportService extends ApiServiceBase {
  SupportService._();
  static final SupportService instance = SupportService._();

  Future<void> sendSupportMessage({
    required String message,
    String? userId,
    String? userName,
    String? userEmail,
  }) async {
    final uri = buildUri('/support_messages');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'message': message,
      }),
    ).timeout(const Duration(seconds: 12));

    if (!isSuccess(response)) {
      throwApiError(response, 'Failed to send support message');
    }

    final senderLabel = [
      if (userName != null && userName.trim().isNotEmpty) userName.trim(),
      if (userEmail != null && userEmail.trim().isNotEmpty) '<${userEmail.trim()}>',
    ].join(' ');

    final notificationResponse = await http.post(
      buildUri('/notifications'),
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'sender_id': userId,
        'title': 'Support request',
        'message': senderLabel.isEmpty ? message : '$senderLabel\n$message',
        'type': 'admin',
        'target_group': 'admin',
      }),
    ).timeout(const Duration(seconds: 12));

    if (!isSuccess(notificationResponse)) {
      throwApiError(notificationResponse, 'Failed to notify admin');
    }
  }
}
