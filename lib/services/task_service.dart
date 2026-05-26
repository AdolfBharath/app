import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/task_submission.dart';
import '../utils/supabase_config.dart';
import 'api_base.dart';
import 'token_service.dart';

class TaskService extends ApiServiceBase {
  TaskService._();
  static final TaskService instance = TaskService._();

  static const _taskSelect =
      'id,batch_id,title,description,file_url,drive_link,deadline,created_by,created_at';
  static const _submissionSelect =
      'id,task_id,title,student_id,student_name,student_email,file_url,file_type,drive_link,submitted_at,status,feedback,is_late,student_done,done_at';

  Future<List<BatchTask>> getBatchTasks(String batchId) async {
    final rows = await getJsonList(
      '/batch_tasks?batch_id=eq.$batchId&select=$_taskSelect&order=created_at.desc&limit=$defaultPageSize',
    );
    return _withSubmissionState(rows);
  }

  Future<List<BatchTask>> _withSubmissionState(
    List<Map<String, dynamic>> taskRows,
  ) async {
    if (taskRows.isEmpty) return const [];

    final tasks = taskRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final taskIds = tasks
        .map((task) => task['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (taskIds.isEmpty) {
      return tasks.map<BatchTask>(BatchTask.fromJson).toList(growable: false);
    }

    final currentUserId = await TokenService.getToken();
    try {
      final submissions = await getJsonList(
        '/task_submissions?task_id=in.(${taskIds.join(',')})&select=$_submissionSelect&order=submitted_at.desc&limit=$expandedPageSize',
      );
      final byTask = <String, List<Map<String, dynamic>>>{};
      for (final submission in submissions) {
        final taskId = submission['task_id']?.toString();
        if (taskId == null || taskId.isEmpty) continue;
        byTask.putIfAbsent(taskId, () => <Map<String, dynamic>>[]).add(submission);
      }

      for (final task in tasks) {
        final taskId = task['id']?.toString() ?? '';
        final taskSubmissions = byTask[taskId] ?? const <Map<String, dynamic>>[];
        final completedStudentIds = <String>{};
        for (final submission in taskSubmissions) {
          if (submission['student_done'] == true) {
            final studentId = submission['student_id']?.toString();
            if (studentId != null && studentId.isNotEmpty) {
              completedStudentIds.add(studentId);
            }
          }
        }

        task['submission_count'] = completedStudentIds.length;
        task['attempt_count'] = taskSubmissions.length;

        if (currentUserId != null && currentUserId.trim().isNotEmpty) {
          Map<String, dynamic>? mine;
          for (final submission in taskSubmissions) {
            if (submission['student_id']?.toString() == currentUserId) {
              mine = submission;
              break;
            }
          }
          if (mine != null) {
            task['my_submission_status'] = mine['status'];
            task['my_submission_feedback'] = mine['feedback'];
            task['my_submission_is_late'] = mine['is_late'];
            task['my_submission_file_url'] = mine['file_url'];
            task['my_submission_drive_link'] = mine['drive_link'];
            task['my_submission_submitted_at'] = mine['submitted_at'];
            task['my_submission_student_done'] = mine['student_done'];
            task['my_submission_done_at'] = mine['done_at'];
          }
        }
      }
    } catch (_) {
      for (final task in tasks) {
        task['submission_count'] ??= 0;
        task['attempt_count'] ??= 0;
      }
    }

    return tasks.map<BatchTask>(BatchTask.fromJson).toList(growable: false);
  }

  Future<BatchTask> createTask({
    required String batchId,
    required String title,
    required String description,
    String? fileUrl,
    String? driveLink,
    DateTime? deadline,
  }) async {
    final uri = buildUri('/batch_tasks');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'batch_id': batchId,
        'title': title,
        'description': description,
        'file_url': fileUrl,
        'drive_link': driveLink,
        'deadline': deadline?.toIso8601String(),
      }),
    );

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
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
      'batch_id': batchId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'drive_link': driveLink,
      'deadline': deadline?.toIso8601String(),
    });
    final headers = await buildAuthHeaders();

    final primary = await http.patch(
      buildUri('/batch_tasks?id=eq.$taskId'),
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
      final fallback = await http.patch(
        buildUri('/batch_tasks?id=eq.$taskId&batch_id=eq.$batchId'),
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
    final userId = await TokenService.getToken();
    if (userId == null || userId.trim().isEmpty) {
      throw ApiException('Not logged in');
    }

    final uri = buildUri('/task_submissions');
    final submittedAt = DateTime.now().toIso8601String();
    final body = <String, dynamic>{
      'task_id': taskId,
      'student_id': userId,
      'file_url': fileUrl,
      'file_type': fileType,
      'drive_link': driveLink,
      'submitted_at': submittedAt,
      if (markDone != null) 'student_done': markDone,
      if (markDone == true) 'done_at': submittedAt,
      if (markDone == true) 'status': 'submitted',
    };
    final headers = await buildAuthHeaders();

    http.Response response;
    final existing = await http
        .get(
          buildUri(
            '/task_submissions?task_id=eq.$taskId&student_id=eq.$userId&select=id&limit=1',
          ),
          headers: headers,
        )
        .catchError((_) => http.Response('', 500));

    if (isSuccess(existing)) {
      final decoded = jsonDecode(existing.body);
      if (decoded is List && decoded.isNotEmpty) {
        final submissionId = (decoded.first as Map)['id']?.toString();
        if (submissionId != null && submissionId.isNotEmpty) {
          response = await http.patch(
            buildUri('/task_submissions?id=eq.$submissionId'),
            headers: headers,
            body: jsonEncode(body),
          );
        } else {
          response = await http.post(uri, headers: headers, body: jsonEncode(body));
        }
      } else {
        response = await http.post(uri, headers: headers, body: jsonEncode(body));
      }
    } else {
      response = await http.post(uri, headers: headers, body: jsonEncode(body));
    }

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
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
      ..fields['task_id'] = taskId;

    request.headers['apikey'] = SupabaseConfig.apiKey;
    request.headers['Authorization'] = 'Bearer ${SupabaseConfig.apiKey}';

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
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw ApiException('Unexpected Drive upload response format');
    }

    throwApiError(response, 'Failed to upload to Google Drive');
  }

  Future<List<TaskSubmission>> getTaskSubmissions(String taskId) async {
    final rows = await getCachedJsonList(
      '/task_submissions?task_id=eq.$taskId&select=$_submissionSelect&order=submitted_at.desc&limit=$defaultPageSize',
      ttl: const Duration(minutes: 2),
    );
    return rows.map<TaskSubmission>(TaskSubmission.fromJson).toList(growable: false);
  }

  Future<TaskSubmission> reviewSubmission({
    required String submissionId,
    required String status,
    String? feedback,
  }) async {
    final uri = buildUri('/task_submissions?id=eq.$submissionId');
    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'status': status,
        'feedback': feedback,
      }),
    );

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic>) {
        return TaskSubmission.fromJson(decoded);
      }
      throw ApiException('Unexpected review response format');
    }

    throwApiError(response, 'Failed to review submission');
  }

  Future<List<TaskSubmission>> getAllMentorSubmissions(List<String> batchIds) async {
    if (batchIds.isEmpty) return [];

    // Fetch all tasks for these batches
    final batchFilter = batchIds.map((id) => 'batch_id.eq.$id').join(',');
    final tasksUri = buildUri(
      '/batch_tasks?or=($batchFilter)&select=id,title,batch_id&limit=$expandedPageSize',
    );
    final tasksResponse = await http.get(tasksUri, headers: await buildAuthHeaders());

    if (!isSuccess(tasksResponse)) return [];

    final tasksData = jsonDecode(tasksResponse.body) as List;
    final taskIds = tasksData.map((t) => t['id'].toString()).toList();

    if (taskIds.isEmpty) return [];

    // Fetch all submissions for these tasks
    final taskFilter = taskIds.map((id) => 'task_id.eq.$id').join(',');
    final subsUri = buildUri(
      '/task_submissions?or=($taskFilter)&select=$_submissionSelect&order=submitted_at.desc&limit=$expandedPageSize',
    );
    final subsResponse = await http.get(subsUri, headers: await buildAuthHeaders());

    if (!isSuccess(subsResponse)) return [];

    final subsData = jsonDecode(subsResponse.body) as List;

    // Map tasks for title lookup
    final taskMap = {
      for (var t in tasksData)
        t['id'].toString(): {
          'title': t['title'].toString(),
          'batch_id': t['batch_id']?.toString(),
        }
    };

    return subsData.map((item) {
      final map = item as Map<String, dynamic>;
      // Inject task title as title if missing
      if (map['title'] == null) {
        map['title'] =
            taskMap[map['task_id'].toString()]?['title'] ?? 'Task Submission';
      }
      map['batch_id'] = taskMap[map['task_id'].toString()]?['batch_id'];
      return TaskSubmission.fromJson(map);
    }).toList();
  }
}
