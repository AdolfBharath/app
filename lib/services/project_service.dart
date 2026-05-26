import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project.dart';
import 'api_base.dart';

/// Domain service for project submission and review API operations.
class ProjectService extends ApiServiceBase {
  ProjectService._();
  static final ProjectService instance = ProjectService._();

  static const _projectSelect =
      'id,title,description,student_id,student_name,batch_id,batch_name,submission_date,status,file_urls,review_notes,reviewed_by,reviewed_date';

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all project submissions (admin / mentor).
  Future<List<Project>> getProjects() async {
    final rows = await getCachedJsonList(
      '/projects?select=$_projectSelect&order=submission_date.desc&limit=$expandedPageSize',
      ttl: const Duration(minutes: 2),
    );
    return rows.map<Project>(Project.fromJson).toList(growable: false);
  }

  /// Mentor-facing alias for [getProjects] — returns raw maps for flexible UI use.
  Future<List<Map<String, dynamic>>> getMentorProjects() async {
    return getCachedJsonList(
      '/projects?select=$_projectSelect&order=submission_date.desc&limit=$expandedPageSize',
      ttl: const Duration(minutes: 2),
    );
  }

  /// Fetch detailed information about a specific project.
  Future<Project> getProjectDetails(String projectId) async {
    final uri = buildUri('/projects?id=eq.$projectId&select=$_projectSelect&limit=1');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic>) {
        return Project.fromJson(decoded);
      }
    }

    // Fallback: Check Task Submissions
    final taskUri = buildUri(
      '/task_submissions?id=eq.$projectId&select=id,task_id,title,student_id,student_name,file_url,submitted_at,status,feedback&limit=1',
    );
    final taskResponse = await http.get(taskUri, headers: await buildAuthHeaders());

    if (isSuccess(taskResponse)) {
      var decoded = jsonDecode(taskResponse.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic>) {
        final map = decoded as Map<String, dynamic>;
        return Project(
          id: map['id'].toString(),
          title: map['title']?.toString() ?? 'Task Submission',
          description: 'Task Submission',
          studentId: map['student_id']?.toString() ?? '',
          studentName: map['student_name']?.toString() ?? 'Student',
          batchId: '',
          batchName: 'Batch Task',
          submissionDate: DateTime.tryParse(map['submitted_at']?.toString() ?? '') ?? DateTime.now(),
          status: _mapProjectStatus(map['status']?.toString()),
          fileUrls: map['file_url'] != null ? [map['file_url']!] : [],
          reviewNotes: map['feedback']?.toString(),
        );
      }
    }

    throwApiError(response, 'Failed to load project details');
  }

  ProjectStatus _mapProjectStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'validated':
      case 'reviewed':
        return ProjectStatus.reviewed;
      case 'rejected':
        return ProjectStatus.rejected;
      case 'in_review':
        return ProjectStatus.inReview;
      default:
        return ProjectStatus.pending;
    }
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
    // Try updating projects table first
    try {
      final uri = buildUri('/projects?id=eq.$projectId');
      final body = <String, dynamic>{
        'status': status,
        'review_notes': reviewNotes,
      };

      final response = await http.patch(
        uri,
        headers: await buildAuthHeaders(),
        body: jsonEncode(body),
      );

      // If we got a success response, it might have updated a project
      if (isSuccess(response)) {
        // If the body is an empty list, it means no project was found with that ID
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) return true;
      }
    } catch (_) {
      // Ignore and try fallback
    }

    // Fallback: Try updating task_submissions
    try {
      // Map ProjectStatus to TaskSubmission status string
      String taskStatus = status.toLowerCase();
      if (status == 'reviewed') taskStatus = 'validated';

      final uri = buildUri('/task_submissions?id=eq.$projectId');
      final response = await http.patch(
        uri,
        headers: await buildAuthHeaders(),
        body: jsonEncode({
          'status': taskStatus,
          'feedback': reviewNotes,
        }),
      );

      if (isSuccess(response)) return true;
    } catch (_) {
      // Ignore
    }

    throw ApiException('Failed to update status for Project/Task $projectId');
  }
}
