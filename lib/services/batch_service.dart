import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/batch.dart';
import '../models/batch_detail.dart';
import '../models/user.dart';
import '../utils/supabase_config.dart';
import 'api_base.dart';
import 'token_service.dart';

/// Domain service for all batch-related API operations.
class BatchService extends ApiServiceBase {
  BatchService._();
  static final BatchService instance = BatchService._();

  static const _batchSelect =
      'id,name,course_id,mentor_id,capacity,enroll_limit,smart_waitlist,status,start_date,progress,enrolled_count';
  static const _userSummarySelect =
      'id,name,email,username,role,batch_id,coins,streak_count,last_active_date,weekly_logins';

  Future<http.Response> _callAdminProxy(String path, String method) async {
    final uri = Uri.parse('${SupabaseConfig.adminProxyUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    switch (method.toUpperCase()) {
      case 'DELETE':
        return http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 12));
      default:
        throw ApiException('Unsupported proxy method: $method');
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all batches (any authenticated user).
  Future<List<Batch>> getBatches() async {
    final rows = await getJsonList(
      '/batches?select=$_batchSelect&order=start_date.desc&limit=$defaultPageSize',
    );
    final enriched = await _withEnrolledCounts(rows);
    return enriched.map<Batch>(Batch.fromJson).toList(growable: false);
  }

  /// Fetch batches assigned to the currently authenticated mentor.
  Future<List<Batch>> getMentorBatches() async {
    final userId = await TokenService.getToken();
    final filter = userId == null || userId.trim().isEmpty
        ? ''
        : '&mentor_id=eq.${userId.trim()}';
    final rows = await getJsonList(
      '/batches?select=$_batchSelect$filter&order=start_date.desc&limit=$defaultPageSize',
    );
    final enriched = await _withEnrolledCounts(rows);
    return enriched.map<Batch>(Batch.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _withEnrolledCounts(
    List<Map<String, dynamic>> batchRows,
  ) async {
    if (batchRows.isEmpty) return batchRows;
    final rows = batchRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final batchIds = rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (batchIds.isEmpty) return rows;

    final counts = <String, Set<String>>{
      for (final id in batchIds) id: <String>{},
    };

    try {
      final relationRows = await getJsonList(
        '/student_batches?batch_id=in.(${batchIds.join(',')})&select=batch_id,student_id&limit=1000',
      );
      for (final row in relationRows) {
        final batchId = row['batch_id']?.toString();
        final studentId = row['student_id']?.toString();
        if (batchId == null || studentId == null) continue;
        counts[batchId]?.add(studentId);
      }
    } catch (_) {}

    try {
      final userRows = await getJsonList(
        '/users?batch_id=in.(${batchIds.join(',')})&role=eq.student&select=id,batch_id&limit=1000',
      );
      for (final row in userRows) {
        final batchId = row['batch_id']?.toString();
        final studentId = row['id']?.toString();
        if (batchId == null || studentId == null) continue;
        counts[batchId]?.add(studentId);
      }
    } catch (_) {}

    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null) continue;
      row['enrolled_count'] = counts[id]?.length ?? row['enrolled_count'] ?? 0;
    }
    return rows;
  }

  /// Fetch detailed information about a specific batch including students.
  Future<BatchDetail> getBatchDetails(String batchId) async {
    try {
      final batchList = await getCachedJsonList(
        '/batches?id=eq.$batchId&select=$_batchSelect&limit=1',
        ttl: const Duration(minutes: 5),
      );
      if (batchList.isEmpty) throw ApiException('Batch not found');
      final batchJson = batchList.first;

      var students = await getJsonList(
        '/users?batch_id=eq.$batchId&role=eq.student&select=$_userSummarySelect&limit=$expandedPageSize',
      );
      final studentIds = students
          .map((student) => student['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final path in [
        '/student_batches?batch_id=eq.$batchId&select=student_id&limit=500',
      ]) {
        try {
          final rows = await getJsonList(path);
          for (final row in rows) {
            final id = (row['student_id'] ?? row['user_id'])?.toString();
            if (id != null && id.isNotEmpty) studentIds.add(id);
          }
        } catch (_) {}
      }
      if (studentIds.isNotEmpty) {
        students = await getJsonList(
          '/users?id=in.(${studentIds.join(',')})&role=eq.student&select=$_userSummarySelect&limit=500',
        );
      }

      Map<String, dynamic>? mentorJson;
      final mentorId = batchJson['mentor_id'];
      if (mentorId != null && mentorId.toString().isNotEmpty) {
        final mentors = await getJsonList(
          '/users?id=eq.$mentorId&select=$_userSummarySelect&limit=1',
        );
        if (mentors.isNotEmpty) mentorJson = mentors.first;
      }

      String? courseName;
      final courseId = batchJson['course_id'];
      if (courseId != null && courseId.toString().isNotEmpty) {
        final courses = await getJsonList(
          '/courses?id=eq.$courseId&select=title',
        );
        if (courses.isNotEmpty) courseName = courses.first['title'];
      }

      List<dynamic> quizAttempts = [];
      List<dynamic> progressRows = [];
      int totalLessons = 0;

      if (students.isNotEmpty) {
        try {
          final studentIds = students.map((s) => s['id']).join(',');
          quizAttempts = await getJsonList(
            '/student_quiz_attempts?student_id=in.($studentIds)&course_id=eq.$courseId&select=student_id,score,total,passed,created_at',
          );
          progressRows = await getJsonList(
            '/student_course_progress?student_id=in.($studentIds)&course_id=eq.$courseId&select=student_id,completed_lessons,quiz_completed',
          );
        } catch (_) {}
      }

      try {
        if (courseId != null && courseId.toString().isNotEmpty) {
          final courses = await getJsonList(
            '/courses?id=eq.$courseId&select=modules&limit=1',
          );
          if (courses.isNotEmpty) {
            final rawModules = courses.first['modules'];
            if (rawModules is List) {
              for (final module in rawModules) {
                if (module is! Map) continue;
                final lessons = module['lessons'];
                if (lessons is List) totalLessons += lessons.length;
              }
            }
          }
        }
      } catch (_) {}

      Map<String, double> studentScores = {};
      Map<String, int> studentQuizTotals = {};
      Map<String, int> studentCompletedLessons = {};

      for (final s in students) {
        final sid = s['id'].toString();
        studentScores[sid] = 0.0;
        studentQuizTotals[sid] = 0;
        studentCompletedLessons[sid] = 0;
      }

      for (final attempt in quizAttempts) {
        final sid = attempt['student_id']?.toString();
        if (sid != null && studentScores.containsKey(sid)) {
          final score = (attempt['score'] as num?)?.toDouble() ?? 0.0;
          final total = (attempt['total'] as num?)?.toInt() ?? 0;
          studentScores[sid] = [
            studentScores[sid] ?? 0.0,
            score,
          ].reduce((a, b) => a > b ? a : b);
          if (total > (studentQuizTotals[sid] ?? 0)) {
            studentQuizTotals[sid] = total;
          }
        }
      }

      for (final row in progressRows) {
        final sid = row['student_id']?.toString();
        if (sid != null && studentCompletedLessons.containsKey(sid)) {
          final completed = row['completed_lessons'];
          studentCompletedLessons[sid] = completed is List
              ? completed.length
              : 0;
        }
      }

      final topPerformers = students.map((s) {
        final sid = s['id'].toString();
        final completedLessons = studentCompletedLessons[sid] ?? 0;
        final progress = totalLessons == 0
            ? 0.0
            : (completedLessons / totalLessons).clamp(0.0, 1.0);
        return {
          'student_id': sid,
          'student_name': s['name'],
          'student_email': s['email'],
          'student_username': s['username'],
          'batch_id': batchId,
          'progress': progress,
          'score': studentScores[sid] ?? 0.0,
          'completed_assignments': completedLessons,
          'total_assignments': totalLessons,
        };
      }).toList();

      topPerformers.sort((a, b) {
        final scoreCompare = (b['score'] as double).compareTo(
          a['score'] as double,
        );
        if (scoreCompare != 0) return scoreCompare;
        return (b['progress'] as double).compareTo(a['progress'] as double);
      });

      for (int i = 0; i < topPerformers.length; i++) {
        topPerformers[i]['rank'] = i + 1;
      }

      double avgProgress = 0.0;
      if (topPerformers.isNotEmpty) {
        avgProgress =
            topPerformers.fold(
              0.0,
              (sum, item) => sum + (item['progress'] as double),
            ) /
            topPerformers.length;
      }

      return BatchDetail.fromJson({
        'batch': batchJson,
        'course_name': courseName,
        'mentor': mentorJson,
        'students': students,
        'top_performers': topPerformers,
        'total_students': students.length,
        'average_progress': avgProgress,
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load batch details: $e');
    }
  }

  /// Fetch top-performing students in a batch.
  Future<List<AppUser>> getTopPerformers(
    String batchId, {
    int limit = 10,
  }) async {
    final uri = buildUri('/batches/$batchId/top-performers?limit=$limit');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map<AppUser>((dynamic item) {
          final map = item as Map<String, dynamic>;
          return AppUser(
            id: map['id']?.toString() ?? '',
            name: map['name'] as String? ?? 'Unknown',
            email: map['email'] as String? ?? '',
            password: '',
            role: UserRole.student,
            username: map['username'] as String?,
            batchId: batchId,
          );
        }).toList();
      }
      throw ApiException('Unexpected top performers response format');
    }

    throwApiError(response, 'Failed to load top performers');
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Create a new batch.
  Future<bool> createBatch({
    required String name,
    required String courseId,
    String? mentorId,
    int? capacity,
    int? enrollLimit,
    bool smartWaitlist = false,
    DateTime? startDate,
  }) async {
    final uri = buildUri('/batches');
    final body = <String, dynamic>{
      'name': name,
      'course_id': courseId,
      'smart_waitlist': smartWaitlist,
    };
    if (mentorId != null && mentorId.isNotEmpty) body['mentor_id'] = mentorId;
    if (capacity != null) body['capacity'] = capacity;
    if (enrollLimit != null) body['enroll_limit'] = enrollLimit;
    if (startDate != null) body['start_date'] = startDate.toIso8601String();

    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to create batch');
  }

  /// Update a batch's mutable fields.
  Future<bool> updateBatch({
    required String batchId,
    String? name,
    String? courseId,
    String? mentorId,
    int? capacity,
    int? enrollLimit,
    bool? smartWaitlist,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = buildUri('/batches?id=eq.$batchId');
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (courseId != null && courseId.isNotEmpty) body['course_id'] = courseId;
    if (mentorId != null && mentorId.isNotEmpty) {
      body['mentor_id'] = mentorId;
    }
    if (capacity != null) body['capacity'] = capacity;
    if (enrollLimit != null) body['enroll_limit'] = enrollLimit;
    if (smartWaitlist != null) body['smart_waitlist'] = smartWaitlist;
    if (startDate != null) body['start_date'] = startDate.toIso8601String();
    if (endDate != null) body['end_date'] = endDate.toIso8601String();
    if (body.isEmpty) return false;

    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to update batch');
  }

  /// Delete a batch by id.
  Future<bool> deleteBatch(String id) async {
    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final response = await _callAdminProxy('/admin/batches/$id', 'DELETE');
      if (isSuccess(response)) return true;
      throwApiError(response, 'Failed to delete batch via proxy');
    }

    await http.patch(
      buildUri('/users?batch_id=eq.$id'),
      headers: await buildAuthHeaders(),
      body: jsonEncode({'batch_id': null}),
    );

    try {
      for (final path in [
        '/student_batches?batch_id=eq.$id',
      ]) {
        await http.delete(buildUri(path), headers: await buildAuthHeaders());
      }

      final tasksResponse = await http.get(
        buildUri('/batch_tasks?batch_id=eq.$id&select=id'),
        headers: await buildAuthHeaders(),
      );
      if (isSuccess(tasksResponse)) {
        final decoded = jsonDecode(tasksResponse.body);
        if (decoded is List && decoded.isNotEmpty) {
          final taskIds = decoded
              .map((task) => task is Map ? task['id']?.toString() ?? '' : '')
              .where((taskId) => taskId.isNotEmpty)
              .toList(growable: false);
          if (taskIds.isNotEmpty) {
            await http.delete(
              buildUri('/task_submissions?task_id=in.(${taskIds.join(',')})'),
              headers: await buildAuthHeaders(),
            );
          }
        }
      }
      await http.delete(
        buildUri('/batch_tasks?batch_id=eq.$id'),
        headers: await buildAuthHeaders(),
      );
      await http.delete(
        buildUri('/batch_chat_posts?batch_id=eq.$id'),
        headers: await buildAuthHeaders(),
      );
      await http.delete(
        buildUri('/batch_chat_members?batch_id=eq.$id'),
        headers: await buildAuthHeaders(),
      );
    } catch (_) {
      // Continue to the batch delete so deployments without these optional
      // tables still work.
    }

    final uri = buildUri('/batches?id=eq.$id');
    final response = await http.delete(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to delete batch');
  }
}
