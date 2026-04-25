import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Domain service for user management API operations.
class UserService extends ApiServiceBase {
  UserService._();
  static final UserService instance = UserService._();

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all users, optionally filtered by [role].
  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    final path = role != null ? '/users?role=$role' : '/users';
    final uri = buildUri(path);
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Map<String, dynamic>>(
                (dynamic item) => item as Map<String, dynamic>)
            .toList();
      }
      throw ApiException('Unexpected users response format');
    }

    throwApiError(response, 'Failed to load users');
  }

  Future<List<Map<String, dynamic>>> getStudentsForCourse(String courseId) async {
    final normalized = courseId.trim();
    if (normalized.isEmpty) return const [];
    final students = await getUsers(role: 'student');
    return students.where((u) => _extractCourseIds(u).contains(normalized)).toList();
  }

  Set<String> _extractCourseIds(Map<String, dynamic> json) {
    final ids = <String>{};

    void add(dynamic v) {
      if (v == null) return;
      final id = v.toString().trim();
      if (id.isNotEmpty) ids.add(id);
    }

    add(json['course_id']);
    add(json['courseId']);
    add(json['enrolled_course_id']);

    final courseIds = json['course_ids'];
    if (courseIds is List) {
      for (final c in courseIds) {
        add(c);
      }
    }

    final courses = json['courses'];
    if (courses is List) {
      for (final c in courses) {
        if (c is Map<String, dynamic>) {
          add(c['id']);
          add(c['course_id']);
        } else {
          add(c);
        }
      }
    }

    return ids;
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Create a new user (admin only).
  /// Returns a map with at minimum { email_sent: bool, email_warning: String? }.
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? senderEmail,
    String? senderPassword,
    List<String>? courseNames,
  }) async {
    final uri = buildUri('/users');
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (senderEmail != null && senderEmail.isNotEmpty) 'senderEmail': senderEmail,
      if (senderPassword != null && senderPassword.isNotEmpty) 'senderPassword': senderPassword,
      if (courseNames != null && courseNames.isNotEmpty) 'courseNames': courseNames,
    };

    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'email_sent': true};
    }
    throwIfUnauthorized(response);
    if (response.statusCode == 409) {
      throw DuplicateEmailException('A user with this email already exists');
    }
    throwApiError(response, 'Failed to create user');
  }

  /// Update mutable fields of a user (admin only).
  Future<bool> updateUser(
    String userId, {
    String? name,
    String? email,
    String? username,
    String? role,
    List<String>? expertise,
    String? batchId,
    bool includeBatchId = false,
    List<String>? courseIds,
    bool includeCourseIds = false,
  }) async {
    final uri = buildUri('/users/$userId');
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (role != null && role.isNotEmpty) body['role'] = role;
    if (expertise != null) body['expertise'] = expertise;
    if (includeBatchId) body['batch_id'] = batchId;
    if (includeCourseIds) body['course_ids'] = courseIds ?? const [];
    if (body.isEmpty) return false;

    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to update user');
  }

  /// Delete a user by id (admin only).
  Future<bool> deleteUser(String id) async {
    final uri = buildUri('/users/$id');
    final response = await http.delete(uri, headers: await buildAuthHeaders());
    return isSuccess(response);
  }

  // ---------------------------------------------------------------------------
  // Email Config
  // ---------------------------------------------------------------------------

  /// Fetch the global SMTP configuration (admin only).
  Future<Map<String, dynamic>> getEmailConfig() async {
    final uri = buildUri('/users/email-config');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throwApiError(response, 'Failed to load email configuration');
  }

  /// Update the global SMTP configuration (admin only).
  Future<bool> updateEmailConfig({
    required String email,
    required String appPassword,
  }) async {
    final uri = buildUri('/users/email-config');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'email': email,
        'appPassword': appPassword,
      }),
    );

    return isSuccess(response);
  }

  /// Assign a course to a user, trying three endpoint patterns for compatibility.
  Future<bool> assignCourseToUser(String userId, String courseId) async {
    var uri = buildUri('/users/$userId/courses/$courseId');
    var response = await http.post(uri, headers: await buildAuthHeaders());

    if (response.statusCode == 404) {
      uri = buildUri('/users/assign-course');
      response = await http.post(
        uri,
        headers: await buildAuthHeaders(),
        body: jsonEncode({'user_id': userId, 'course_id': courseId}),
      );
    }

    if (response.statusCode == 404) {
      uri = buildUri('/courses/$courseId/assign');
      response = await http.post(
        uri,
        headers: await buildAuthHeaders(),
        body: jsonEncode({'user_id': userId}),
      );
    }

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to assign course');
  }
}
