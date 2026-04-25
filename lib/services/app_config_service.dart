import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class AppConfigService extends ApiServiceBase {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Future<Map<String, dynamic>> getConfig() async {
    try {
      // Try the root app-config first
      final response = await http.get(buildUri('/app-config'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
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
      // Use snake_case for backend compatibility
      final body = {
        'registration_form_url': data['registrationFormUrl'] ?? data['registration_form_url'],
      };

      final response = await http.post(
        buildUri('/app-config'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      debugPrint('Failed to update config: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('AppConfigService.updateConfig error: $e');
      return false;
    }
  }
}
