import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/batch.dart';
import '../models/batch_detail.dart';
import '../models/user.dart';
import 'api_base.dart';

/// Domain service for all batch-related API operations.
class BatchService extends ApiServiceBase {
  BatchService._();
  static final BatchService instance = BatchService._();

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all batches (any authenticated user).
  Future<List<Batch>> getBatches() async {
    final uri = buildUri('/batches');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Batch>((dynamic item) =>
                Batch.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected batches response format');
    }

    throwApiError(response, 'Failed to load batches');
  }

  /// Fetch batches assigned to the currently authenticated mentor.
  Future<List<Batch>> getMentorBatches() async {
    final uri = buildUri('/mentor/batches');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Batch>((dynamic item) =>
                Batch.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected mentor batches response format');
    }

    throwApiError(response, 'Failed to load mentor batches');
  }

  /// Fetch detailed information about a specific batch including students.
  Future<BatchDetail> getBatchDetails(String batchId) async {
    final uri = buildUri('/batches/$batchId/details');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return BatchDetail.fromJson(decoded);
      }
      throw ApiException('Unexpected batch details response format');
    }

    throwApiError(response, 'Failed to load batch details');
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
    final uri = buildUri('/batches/$batchId');
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

    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to update batch');
  }

  /// Delete a batch by id.
  Future<bool> deleteBatch(String id) async {
    final uri = buildUri('/batches/$id');
    final response =
        await http.delete(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to delete batch');
  }
}
