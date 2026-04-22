import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Domain service for notification and announcement API operations.
class NotificationService extends ApiServiceBase {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch notifications visible to the current mentor / student.
  Future<List<Map<String, dynamic>>> getMentorNotifications() async {
    final uri = buildUri('/notifications');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Map<String, dynamic>>(
                (dynamic item) => item as Map<String, dynamic>)
            .toList();
      }
      throw ApiException('Unexpected notifications response format');
    }

    throwApiError(response, 'Failed to load notifications');
  }

  /// Fetch admin inbox notifications.
  Future<List<Map<String, dynamic>>> getAdminInboxNotifications() async {
    final uri = buildUri('/notifications/admin-inbox');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Map<String, dynamic>>(
                (dynamic item) => item as Map<String, dynamic>)
            .toList();
      }
      throw ApiException('Unexpected admin inbox response format');
    }

    throwApiError(response, 'Failed to load admin inbox notifications');
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Broadcast an announcement to a target group.
  ///
  /// [targetGroup] should be `'student'`, `'mentor'`, or `'both'`.
  Future<bool> sendAnnouncement({
    required String title,
    required String message,
    required String targetGroup,
  }) async {
    final uri = buildUri('/notifications/announcements');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'message': message,
        'targetGroup': targetGroup,
      }),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to send announcement');
  }

  Future<bool> sendBatchAnnouncement({
    required String batchId,
    required String title,
    required String message,
  }) async {
    final uri = buildUri('/notifications/batches/$batchId/announcements');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'message': message,
      }),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to send batch announcement');
  }
}
