import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project.dart';
import 'api_base.dart';

/// Domain service for project submission and review API operations.
class ProjectService extends ApiServiceBase {
  ProjectService._();
  static final ProjectService instance = ProjectService._();

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all project submissions (admin / mentor).
  Future<List<Project>> getProjects() async {
    final uri = buildUri('/projects');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Project>((dynamic item) =>
                Project.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected projects response format');
    }

    throwApiError(response, 'Failed to load projects');
  }

  /// Mentor-facing alias for [getProjects] — returns raw maps for flexible UI use.
  Future<List<Map<String, dynamic>>> getMentorProjects() async {
    final uri = buildUri('/projects');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Map<String, dynamic>>(
                (dynamic item) => item as Map<String, dynamic>)
            .toList();
      }
      throw ApiException('Unexpected projects response format');
    }

    throwApiError(response, 'Failed to load mentor projects');
  }

  /// Fetch detailed information about a specific project.
  Future<Project> getProjectDetails(String projectId) async {
    final uri = buildUri('/projects/$projectId');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return Project.fromJson(decoded);
      }
      throw ApiException('Unexpected project details response format');
    }

    throwApiError(response, 'Failed to load project details');
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Update the review status of a project.
  Future<bool> updateProjectStatus(
    String projectId, {
    required String status,
    String? reviewNotes,
  }) async {
    final uri = buildUri('/projects/$projectId/status');
    final body = <String, dynamic>{'status': status};
    if (reviewNotes != null && reviewNotes.isNotEmpty) {
      body['review_notes'] = reviewNotes;
    }

    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to update project status');
  }
}
