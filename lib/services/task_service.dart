import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/task_submission.dart';
import 'api_base.dart';
import 'token_service.dart';

class TaskService extends ApiServiceBase {
  TaskService._();
  static final TaskService instance = TaskService._();

  Future<List<BatchTask>> getBatchTasks(String batchId) async {
    final uri = buildUri('/batches/$batchId/tasks');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<BatchTask>((item) => BatchTask.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected tasks response format');
    }

    throwApiError(response, 'Failed to load tasks');
  }

  Future<BatchTask> createTask({
    required String batchId,
    required String title,
    required String description,
    String? fileUrl,
    String? driveLink,
    DateTime? deadline,
  }) async {
    final uri = buildUri('/batches/$batchId/tasks');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'driveLink': driveLink,
        'deadline': deadline?.toIso8601String(),
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return BatchTask.fromJson(decoded);
      }
      throw ApiException('Unexpected create task response format');
    }

    throwApiError(response, 'Failed to create task');
  }

  Future<BatchTask> updateTask({
    required String taskId,
    required String batchId,
    required String title,
    required String description,
    String? fileUrl,
    String? driveLink,
    DateTime? deadline,
  }) async {
    final body = jsonEncode({
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'driveLink': driveLink,
      'deadline': deadline?.toIso8601String(),
    });
    final headers = await buildAuthHeaders();

    final primary = await http.put(
      buildUri('/tasks/$taskId'),
      headers: headers,
      body: body,
    );

    if (isSuccess(primary)) {
      final decoded = jsonDecode(primary.body);
      if (decoded is Map<String, dynamic>) {
        return BatchTask.fromJson(decoded);
      }
      throw ApiException('Unexpected update task response format');
    }

    // Backward compatibility for deployments exposing batch-scoped task update.
    if (primary.statusCode == 404) {
      final fallback = await http.put(
        buildUri('/batches/$batchId/tasks/$taskId'),
        headers: headers,
        body: body,
      );
      if (isSuccess(fallback)) {
        final decoded = jsonDecode(fallback.body);
        if (decoded is Map<String, dynamic>) {
          return BatchTask.fromJson(decoded);
        }
        throw ApiException('Unexpected update task response format');
      }
      throwApiError(fallback, 'Failed to update task');
    }

    throwApiError(primary, 'Failed to update task');
  }

  Future<TaskSubmission> submitTask({
    required String taskId,
    String? fileUrl,
    String? fileType,
    String? driveLink,
    bool? markDone,
  }) async {
    final uri = buildUri('/tasks/$taskId/submissions');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'fileUrl': fileUrl,
        'fileType': fileType,
        'driveLink': driveLink,
        if (markDone != null) 'markDone': markDone,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return TaskSubmission.fromJson(decoded);
      }
      throw ApiException('Unexpected submit response format');
    }

    throwApiError(response, 'Failed to submit task');
  }

  Future<Map<String, dynamic>> uploadSubmissionToDrive({
    required String taskId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    String? mimeType,
  }) async {
    if (fileBytes == null && (filePath == null || filePath.trim().isEmpty)) {
      throw ApiException('Missing file data for upload');
    }

    final uri = buildUri('/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['taskId'] = taskId;

    final token = await TokenService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath!,
          filename: fileName,
        ),
      );
    }

    if (mimeType != null && mimeType.trim().isNotEmpty) {
      request.fields['mimeType'] = mimeType;
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final response = http.Response(
      body,
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      reasonPhrase: streamed.reasonPhrase,
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw ApiException('Unexpected Drive upload response format');
    }

    throwApiError(response, 'Failed to upload to Google Drive');
  }

  Future<List<TaskSubmission>> getTaskSubmissions(String taskId) async {
    final uri = buildUri('/tasks/$taskId/submissions');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<TaskSubmission>((item) =>
                TaskSubmission.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected submissions response format');
    }

    throwApiError(response, 'Failed to load submissions');
  }

  Future<TaskSubmission> reviewSubmission({
    required String submissionId,
    required String status,
    String? feedback,
  }) async {
    final uri = buildUri('/submissions/$submissionId/review');
    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'status': status,
        'feedback': feedback,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return TaskSubmission.fromJson(decoded);
      }
      throw ApiException('Unexpected review response format');
    }

    throwApiError(response, 'Failed to review submission');
  }
}
