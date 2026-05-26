import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class AppConfigService extends ApiServiceBase {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Future<Map<String, dynamic>> getConfig() async {
    try {
      final response = await http.get(
        buildUri('/app_config'),
        headers: await buildAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return decoded.first as Map<String, dynamic>;
        }
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return {};
    } catch (e) {
      debugPrint('AppConfigService.getConfig error: $e');
      return {};
    }
  }

  Future<bool> updateConfig(Map<String, dynamic> data) async {
    try {
      final headers = await buildAuthHeaders();
      final body = {
        if (data.containsKey('registrationFormUrl') ||
            data.containsKey('registration_form_url'))
          'registration_form_url':
              data['registrationFormUrl'] ?? data['registration_form_url'],
        if (data.containsKey('studentReferenceFormUrl') ||
            data.containsKey('student_reference_form_url'))
          'student_reference_form_url':
              data['studentReferenceFormUrl'] ??
              data['student_reference_form_url'],
        if (data.containsKey('courseReviewFormUrl') ||
            data.containsKey('course_review_form_url'))
          'course_review_form_url':
              data['courseReviewFormUrl'] ?? data['course_review_form_url'],
      };

      // Get current config to find ID
      final currentConfig = await getConfig();
      http.Response response;

      if (currentConfig.containsKey('id')) {
        // Patch existing
        response = await http.patch(
          buildUri('/app_config?id=eq.${currentConfig['id']}'),
          headers: headers,
          body: jsonEncode(body),
        );
      } else {
        // Insert new
        response = await http.post(
          buildUri('/app_config'),
          headers: headers,
          body: jsonEncode(body),
        );
      }

      if (isSuccess(response)) return true;

      debugPrint(
        'Failed to update config: ${response.statusCode} - ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('AppConfigService.updateConfig error: $e');
      return false;
    }
  }
}
