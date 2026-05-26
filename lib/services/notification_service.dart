import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import '../utils/supabase_config.dart';

/// Domain service for notification and announcement API operations.
class NotificationService extends ApiServiceBase {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _notificationSelect =
      'id,title,message,type,target_group,action_url,image_url,read,created_at,sender_id';
  static const _legacyNotificationSelect =
      'id,title,message,type,target_group,read,created_at,sender_id';

  static String get _expiryCutoff =>
      DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

  Future<http.Response> _callAdminProxy(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${SupabaseConfig.adminProxyUrl}$path');
    return http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch notifications visible to the current mentor / student.
  Future<List<Map<String, dynamic>>> getMentorNotifications() async {
    return _getNotifications(
      '/notifications?created_at=gte.$_expiryCutoff&select={select}&order=created_at.desc&limit=$defaultPageSize',
    );
  }

  /// Fetch admin inbox notifications.
  Future<List<Map<String, dynamic>>> getAdminInboxNotifications() async {
    return _getNotifications(
      '/notifications?type=eq.admin&created_at=gte.$_expiryCutoff&select={select}&order=created_at.desc&limit=$defaultPageSize',
    );
  }

  Future<List<Map<String, dynamic>>> _getNotifications(String pathTemplate) async {
    try {
      return await getJsonList(
        pathTemplate.replaceFirst('{select}', _notificationSelect),
      );
    } on ApiException catch (error) {
      final message = error.message.toLowerCase();
      final missingOptionalColumn = message.contains('action_url') ||
          message.contains('image_url');
      if (!missingOptionalColumn) rethrow;
      return getJsonList(
        pathTemplate.replaceFirst('{select}', _legacyNotificationSelect),
      );
    }
  }

  Future<void> deleteExpiredNotifications() async {
    final uri = buildUri('/notifications?created_at=lt.$_expiryCutoff');
    final response = await http.delete(
      uri,
      headers: await buildAuthHeaders(),
    );

    if (isSuccess(response)) return;
    throwApiError(response, 'Failed to delete expired notifications');
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
    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final response = await _callAdminProxy('/admin/announcements', {
        'title': title,
        'message': message,
        'target_group': targetGroup,
      });
      if (isSuccess(response)) {
        invalidateCache('/notifications');
        return true;
      }
      throwApiError(response, 'Failed to send announcement via proxy');
    }

    final uri = buildUri('/notifications');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'message': message,
        'target_group': targetGroup,
        'type': 'announcement',
      }),
    );

    if (isSuccess(response)) {
      invalidateCache('/notifications');
      return true;
    }
    throwApiError(response, 'Failed to send announcement');
  }

  Future<bool> sendBatchAnnouncement({
    required String batchId,
    required String title,
    required String message,
  }) async {
    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final response = await _callAdminProxy(
        '/admin/batches/$batchId/announcements',
        {
          'title': title,
          'message': message,
        },
      );
      if (isSuccess(response)) {
        invalidateCache('/notifications');
        return true;
      }
      throwApiError(response, 'Failed to send batch announcement via proxy');
    }

    final uri = buildUri('/notifications');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'message': message,
        'target_group': 'student',
        'type': 'announcement',
      }),
    );

    if (isSuccess(response)) {
      invalidateCache('/notifications');
      return true;
    }
    throwApiError(response, 'Failed to send batch announcement');
  }

  Future<bool> markNotificationRead(String notificationId) async {
    final normalized = notificationId.trim();
    if (normalized.isEmpty) return false;
    final uri = buildUri('/notifications?id=eq.$normalized');
    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({'read': true}),
    );

    if (isSuccess(response)) {
      invalidateCache('/notifications');
      return true;
    }
    throwApiError(response, 'Failed to mark notification as read');
  }

  /// Permanently deletes a notification from the backend.
  /// Returns [true] on success; silently returns [false] if the id is blank.
  Future<bool> deleteNotification(String notificationId) async {
    final normalized = notificationId.trim();
    if (normalized.isEmpty) return false;
    final uri = buildUri('/notifications?id=eq.$normalized');
    final response = await http.delete(
      uri,
      headers: await buildAuthHeaders(),
    );

    if (isSuccess(response)) {
      invalidateCache('/notifications');
      return true;
    }
    throwApiError(response, 'Failed to delete notification');
  }
}
