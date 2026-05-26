import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import '../utils/supabase_config.dart';

/// Domain service for user management API operations.
class UserService extends ApiServiceBase {
  UserService._();
  static final UserService instance = UserService._();

  static const _safeUserSelect =
      'id,name,email,role,username,admin_no,referral_key,phone,batch_id,profile_pic,expertise,coins,streak_count,last_active_date,weekly_logins,created_at,user_courses:user_courses(course_id),student_batches:student_batches(batch_id)';
  static const _fallbackUserSelect =
      'id,name,email,role,username,admin_no,phone,batch_id,profile_pic,expertise,coins,streak_count,last_active_date,weekly_logins,created_at';
  static const _minimalUserSelect = 'id,name,email,role,created_at';

  // Helper to call the optional admin proxy if configured. The proxy
  // runs with the Supabase `service_role` key so client apps do not
  // need to hold elevated credentials.
  Future<http.Response> _callAdminProxy(String path, String method, [dynamic body]) async {
    final base = SupabaseConfig.adminProxyUrl;
    final uri = Uri.parse(base + path);
    final headers = <String, String>{'Content-Type': 'application/json'};
    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
      case 'POST':
        return await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      case 'PATCH':
        return await http.patch(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      case 'DELETE':
        return await http.delete(uri, headers: headers).timeout(const Duration(seconds: 12));
      default:
        throw Exception('Unsupported proxy method: $method');
    }
  }


  // ---------------------------------------------------------------------------
  // Profile Picture Upload
  // ---------------------------------------------------------------------------

  Future<String> uploadAvatar(String userId, String fileName, String mimeType, List<int> bytes) async {
    final uri = buildUri('/storage/v1/object/avatars/$userId/$fileName');
    final baseUrl = SupabaseConfig.baseUrl.endsWith('/')
        ? SupabaseConfig.baseUrl.substring(0, SupabaseConfig.baseUrl.length - 1)
        : SupabaseConfig.baseUrl;

    final headers = await buildAuthHeaders();
    headers['Content-Type'] = mimeType;

    final response = await http.post(
      uri,
      headers: headers,
      body: bytes,
    );

    if (isSuccess(response)) {
      return '$baseUrl/storage/v1/object/public/avatars/$userId/$fileName';
    } else {
      // It might exist, so try PUT
      final putResponse = await http.put(
        uri,
        headers: headers,
        body: bytes,
      );
      if (isSuccess(putResponse)) {
        return '$baseUrl/storage/v1/object/public/avatars/$userId/$fileName';
      }
      throwApiError(putResponse, 'Failed to upload avatar');
    }
  }
  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all users, optionally filtered by [role].
  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    // If an admin proxy is configured, use it for admin-level reads.
    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final qp = role != null ? '?role=${Uri.encodeComponent(role)}' : '';
      try {
        final resp = await _callAdminProxy('/admin/users$qp', 'GET');
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final dynamic decoded = jsonDecode(resp.body);
          if (decoded is List) return decoded.cast<Map<String, dynamic>>();
          return [];
        }
      } catch (_) {
        // Fall through to the public Supabase read path below. This keeps the
        // directory usable if the optional local admin proxy is not running.
      }
    }

    String pathForSelect(String select) {
      final selectParam = 'select=$select';
      return role != null
          ? '/users?role=eq.$role&$selectParam'
          : '/users?$selectParam';
    }

    Future<List<Map<String, dynamic>>?> tryFetch(String select) async {
      final response = await http.get(
        buildUri(pathForSelect(select)),
        headers: await buildAuthHeaders(),
      );
      if (isSuccess(response)) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
        return [];
      }
      return null;
    }

    final fullRows = await tryFetch(_safeUserSelect);
    if (fullRows != null) return _withCourseAssignments(fullRows);

    final fallbackRows = await tryFetch(_fallbackUserSelect);
    if (fallbackRows != null) return _withCourseAssignments(fallbackRows);

    final minimalResponse = await http.get(
      buildUri(pathForSelect(_minimalUserSelect)),
      headers: await buildAuthHeaders(),
    );
    if (isSuccess(minimalResponse)) {
      final dynamic decoded = jsonDecode(minimalResponse.body);
      if (decoded is List) {
        return _withCourseAssignments(decoded.cast<Map<String, dynamic>>());
      }
      return [];
    }

    throwApiError(minimalResponse, 'Failed to load users');
  }

  Future<List<Map<String, dynamic>>> getStudentsForCourse(String courseId) async {
    final normalized = courseId.trim();
    if (normalized.isEmpty) return const [];
    final students = await getUsers(role: 'student');
    return students.where((u) => _extractCourseIds(u).contains(normalized)).toList();
  }

  Future<List<String>> getUserCourseIds(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return const [];
    final uri = buildUri('/user_courses?user_id=eq.$normalized&select=course_id');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => (e is Map ? e['course_id'] : null)?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    }

    final fallbackResponse = await http.get(
      buildUri('/users?id=eq.$normalized&select=course_ids&limit=1'),
      headers: await buildAuthHeaders(),
    );
    if (isSuccess(fallbackResponse)) {
      final decoded = jsonDecode(fallbackResponse.body);
      if (decoded is List && decoded.isNotEmpty) {
        final raw = (decoded.first as Map)['course_ids'];
        if (raw is List) {
          return raw
              .map((id) => id?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
        }
      }
      return const [];
    }

    throwApiError(response, 'Failed to load user course assignments');
  }

  Future<List<Map<String, dynamic>>> _withCourseAssignments(
    List<Map<String, dynamic>> users,
  ) async {
    if (users.isEmpty) return users;
    if (users.any((user) => _extractCourseIds(user).isNotEmpty)) return users;

    try {
      final userIds = users
          .map((user) => user['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (userIds.isEmpty) return users;

      final rows = await getJsonList(
        '/user_courses?user_id=in.(${userIds.join(',')})&select=user_id,course_id&limit=500',
      );
      final byUser = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final userId = row['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        byUser.putIfAbsent(userId, () => <Map<String, dynamic>>[]).add(row);
      }

      return users.map((user) {
        final userId = user['id']?.toString();
        final assignments = userId == null ? null : byUser[userId];
        if (assignments == null || assignments.isEmpty) return user;
        return <String, dynamic>{
          ...user,
          'user_courses': assignments,
        };
      }).toList(growable: false);
    } catch (_) {
      return users;
    }
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

    final userCourses = json['user_courses'];
    if (userCourses is List) {
      for (final c in userCourses) {
        if (c is Map<String, dynamic>) {
          add(c['course_id']);
          final nestedCourse = c['courses'];
          if (nestedCourse is Map<String, dynamic>) add(nestedCourse['id']);
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
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (courseNames != null && courseNames.isNotEmpty) 'courseNames': courseNames,
    };

    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final resp = await _callAdminProxy('/admin/create-user', 'POST', body);
      if (isSuccess(resp)) {
        var decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
        if (decoded is Map<String, dynamic>) return decoded;
        return {'email_sent': true};
      }
      if (resp.statusCode == 409) {
        throw DuplicateEmailException('A user with this email already exists');
      }
      throw ApiException('Failed to create user via proxy (code ${resp.statusCode})');
    }

    final directBody = Map<String, dynamic>.from(body)..remove('courseNames');
    final response = await http.post(
      buildUri('/users'),
      headers: await buildAuthHeaders(),
      body: jsonEncode(directBody),
    );

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          'email_sent': false,
          'email_warning':
              'User created. Welcome email requires the hosted admin proxy.',
        };
      }
      return {
        'email_sent': false,
        'email_warning':
            'User created. Welcome email requires the hosted admin proxy.',
      };
    }

    if (response.statusCode == 409 || response.body.contains('23505')) {
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
    String? profilePic,
    List<String>? expertise,
    String? batchId,
    bool includeBatchId = false,
    List<String>? courseIds,
    bool includeCourseIds = false,
  }) async {
    final uri = buildUri('/users?id=eq.$userId');
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (role != null && role.isNotEmpty) body['role'] = role;
    if (profilePic != null) body['profile_pic'] = profilePic;
    if (expertise != null) body['expertise'] = expertise;
    if (includeBatchId && !includeCourseIds) body['batch_id'] = batchId;

    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      // Update main user fields via proxy
      if (body.isNotEmpty) {
        final resp = await _callAdminProxy('/admin/update-user/$userId', 'PATCH', body);
        if (!isSuccess(resp)) {
          throw ApiException('Failed to update user via proxy (code ${resp.statusCode})');
        }
      }

      if (includeCourseIds) {
        final resp = await _callAdminProxy('/admin/update-user/$userId/course-assignments', 'POST', {
          'courseIds': courseIds ?? [],
        });
        if (!isSuccess(resp)) {
          throw ApiException('Failed to update user courses via proxy (code ${resp.statusCode})');
        }
      }

      if (includeBatchId) {
        if (batchId == null || batchId.trim().isEmpty) {
          final resp = await _callAdminProxy('/admin/remove-all-batches', 'POST', {
            'userId': userId,
          });
          if (!isSuccess(resp)) {
            throw ApiException('Failed to clear user batches via proxy (code ${resp.statusCode})');
          }
        } else {
          final resp = await _callAdminProxy('/admin/assign-batch', 'POST', {
            'userId': userId,
            'batchId': batchId,
          });
          if (!isSuccess(resp)) {
            throw ApiException('Failed to assign user to batch via proxy (code ${resp.statusCode})');
          }
        }
      }

      return true;
    }

    if (body.isNotEmpty) {
      final response = await http.patch(
        uri,
        headers: await buildAuthHeaders(),
        body: jsonEncode(body),
      );
      if (!isSuccess(response)) {
        throwApiError(response, 'Failed to update user');
      }
    }

    if (includeBatchId) {
      await _setBatchAssignment(userId, batchId);
    }

    if (includeCourseIds) {
      final current = await getUserCourseIds(userId).catchError(
        (_) => <String>[],
      );
      final next = (courseIds ?? const <String>[]).toSet();
      await updateUserCourseAssignments(
        userId,
        addCourseIds: next.difference(current.toSet()).toList(growable: false),
        removeCourseIds:
            current.toSet().difference(next).toList(growable: false),
      );
    }

    return true;
  }

  /// Delete a user by id (admin only).
  Future<bool> deleteUser(String id) async {
    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final resp = await _callAdminProxy('/admin/user/$id', 'DELETE');
      return isSuccess(resp);
    }

    final uri = buildUri('/users?id=eq.$id');
    final response = await http.delete(uri, headers: await buildAuthHeaders());
    return isSuccess(response);
  }

  // ---------------------------------------------------------------------------
  // Email Config
  // ---------------------------------------------------------------------------

  /// Fetch the global SMTP configuration (admin only).
  Future<Map<String, dynamic>> getEmailConfig() async {
    final uri = buildUri('/email_config');
    final response = await http
        .get(uri, headers: await buildAuthHeaders())
        .timeout(const Duration(seconds: 12));

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    }

    throwApiError(response, 'Failed to load email configuration');
  }

  /// Update the global SMTP configuration (admin only).
  Future<bool> updateEmailConfig({
    required String email,
    required String appPassword,
  }) async {
    final currentConfig = await getEmailConfig();
    http.Response response;

    final body = jsonEncode({
      'email': email,
      'app_password': appPassword,
    });

    if (currentConfig.containsKey('id')) {
      final uri = buildUri('/email_config?id=eq.${currentConfig['id']}');
      response = await http.patch(
        uri,
        headers: await buildAuthHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 12));
    } else {
      final uri = buildUri('/email_config');
      response = await http.post(
        uri,
        headers: await buildAuthHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 12));
    }

    return isSuccess(response);
  }

  /// Assign a course to a user, trying three endpoint patterns for compatibility.
  Future<bool> assignCourseToUser(String userId, String courseId) async {
    final uri = buildUri('/user_courses');
    var response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({'user_id': userId, 'course_id': courseId}),
    );

    if (!isSuccess(response) && response.statusCode != 409) {
      throwApiError(response, 'Failed to assign course');
    }

    final progressUri = buildUri('/student_course_progress');
    await http.post(
      progressUri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'student_id': userId,
        'course_id': courseId,
        'completed_lessons': [],
        'completed_modules': [],
        'rewarded_modules': [],
      }),
    ).catchError((_) => http.Response('', 500));

    return true;
  }

  Future<bool> assignUserToBatch(String userId, String batchId) async {
    final normalizedUserId = userId.trim();
    final normalizedBatchId = batchId.trim();
    if (normalizedUserId.isEmpty || normalizedBatchId.isEmpty) return false;

    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final resp = await _callAdminProxy('/admin/assign-batch', 'POST', {
        'userId': normalizedUserId,
        'batchId': normalizedBatchId,
      });
      if (isSuccess(resp)) return true;
      throw ApiException('Failed to assign student to batch via proxy (code ${resp.statusCode})');
    }

    await _patchPrimaryBatchIfEmpty(normalizedUserId, normalizedBatchId);
    await _insertBatchMembership(normalizedUserId, normalizedBatchId);
    return true;
  }

  Future<bool> removeUserFromBatch(String userId, String batchId) async {
    final normalizedUserId = userId.trim();
    final normalizedBatchId = batchId.trim();
    if (normalizedUserId.isEmpty || normalizedBatchId.isEmpty) return false;

    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final resp = await _callAdminProxy('/admin/remove-batch', 'POST', {
        'userId': normalizedUserId,
        'batchId': normalizedBatchId,
      });
      if (isSuccess(resp)) return true;
      throw ApiException('Failed to remove student from batch via proxy (code ${resp.statusCode})');
    }

    final headers = await buildAuthHeaders();
    for (final path in [
      '/student_batches?student_id=eq.$normalizedUserId&batch_id=eq.$normalizedBatchId',
    ]) {
      await http
          .delete(buildUri(path), headers: headers)
          .catchError((_) => http.Response('', 500));
    }

    await http
        .patch(
          buildUri('/users?id=eq.$normalizedUserId&batch_id=eq.$normalizedBatchId'),
          headers: headers,
          body: jsonEncode({'batch_id': null}),
        )
        .catchError((_) => http.Response('', 500));
    return true;
  }

  Future<void> _setBatchAssignment(String userId, String? batchId) async {
    if (batchId != null && batchId.trim().isNotEmpty) {
      await assignUserToBatch(userId, batchId);
      return;
    }

    final headers = await buildAuthHeaders();
    var updated = false;

    final userResponse = await http
        .patch(
          buildUri('/users?id=eq.$userId'),
          headers: headers,
          body: jsonEncode({'batch_id': batchId}),
        )
        .catchError((_) => http.Response('', 500));
    updated = updated || isSuccess(userResponse);

    for (final path in [
      '/student_batches?student_id=eq.$userId',
    ]) {
      await http
          .delete(buildUri(path), headers: headers)
          .catchError((_) => http.Response('', 500));
    }

    if (batchId != null && batchId.trim().isNotEmpty) {
      for (final entry in [
        MapEntry('/student_batches', {'student_id': userId, 'batch_id': batchId}),
      ]) {
        final response = await http
            .post(
              buildUri(entry.key),
              headers: headers,
              body: jsonEncode(entry.value),
            )
            .catchError((_) => http.Response('', 500));
        updated = updated || isSuccess(response) || response.statusCode == 409;
      }
    }

    if (!updated) {
      throw ApiException('Failed to update batch assignment');
    }
  }

  Future<void> _patchPrimaryBatchIfEmpty(String userId, String batchId) async {
    final headers = await buildAuthHeaders();
    try {
      final rows = await getJsonList(
        '/users?id=eq.$userId&select=id,batch_id&limit=1',
      );
      final current = rows.isEmpty ? null : rows.first['batch_id']?.toString();
      if (current != null && current.isNotEmpty) return;
    } catch (_) {}

    await http
        .patch(
          buildUri('/users?id=eq.$userId'),
          headers: headers,
          body: jsonEncode({'batch_id': batchId}),
        )
        .catchError((_) => http.Response('', 500));
  }

  Future<void> _insertBatchMembership(String userId, String batchId) async {
    final headers = await buildAuthHeaders();
    var inserted = false;

    for (final entry in [
      MapEntry('/student_batches', {'student_id': userId, 'batch_id': batchId}),
    ]) {
      final response = await http
          .post(
            buildUri(entry.key),
            headers: headers,
            body: jsonEncode(entry.value),
          )
          .catchError((_) => http.Response('', 500));
      inserted = inserted || isSuccess(response) || response.statusCode == 409;
    }

    if (!inserted) {
      throw ApiException('Failed to assign student to batch');
    }
  }

  Future<void> updateUserCourseAssignments(
    String userId, {
    List<String> addCourseIds = const [],
    List<String> removeCourseIds = const [],
  }) async {
    final headers = await buildAuthHeaders();
    var relationTableFailed = false;

    if (removeCourseIds.isNotEmpty) {
      final removed = removeCourseIds.join(',');
      final userCoursesUri =
          buildUri('/user_courses?user_id=eq.$userId&course_id=in.($removed)');
      final userCoursesResponse =
          await http.delete(userCoursesUri, headers: headers);
      if (!isSuccess(userCoursesResponse)) {
        relationTableFailed = true;
      }

      final progressUri = buildUri(
        '/student_course_progress?student_id=eq.$userId&course_id=in.($removed)',
      );
      await http
          .delete(progressUri, headers: headers)
          .catchError((_) => http.Response('', 500));
    }

    if (addCourseIds.isNotEmpty) {
      for (final courseId in addCourseIds) {
        final userCoursesResponse = await http.post(
          buildUri('/user_courses'),
          headers: headers,
          body: jsonEncode({'user_id': userId, 'course_id': courseId}),
        );
        if (!isSuccess(userCoursesResponse) &&
            userCoursesResponse.statusCode != 409) {
          relationTableFailed = true;
        }
      }

      final progressInserts = addCourseIds
          .map(
            (cid) => {
              'student_id': userId,
              'course_id': cid,
              'completed_lessons': [],
              'completed_modules': [],
              'rewarded_modules': [],
            },
          )
          .toList(growable: false);

      await http.post(
        buildUri('/student_course_progress'),
        headers: headers,
        body: jsonEncode(progressInserts),
      ).catchError((_) => http.Response('', 500));
    }

    if (relationTableFailed) {
      final current = await getUserCourseIds(userId).catchError(
        (_) => <String>[],
      );
      final next = current.toSet()
        ..addAll(addCourseIds)
        ..removeAll(removeCourseIds);
      final response = await http.patch(
        buildUri('/users?id=eq.$userId'),
        headers: headers,
        body: jsonEncode({'course_ids': next.toList(growable: false)}),
      );
      if (!isSuccess(response)) {
        throwApiError(response, 'Failed to update course assignments');
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path) async {
    final optimizedPath = _optimizeReadPath(path);
    final uri = buildUri(optimizedPath);
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    }
    return [];
  }

  String _optimizeReadPath(String path) {
    if (!path.startsWith('/')) return path;
    final hasSelect = path.contains('select=');
    final hasLimit = path.contains('limit=');
    var next = path;
    String separator() => next.contains('?') ? '&' : '?';
    if (!hasSelect) {
      if (next.startsWith('/users')) {
        next = '$next${separator()}select=$_fallbackUserSelect';
      } else if (next.startsWith('/notifications')) {
        next =
            '$next${separator()}select=id,title,message,type,target_group,read,created_at,sender_id';
      } else if (next.startsWith('/task_submissions')) {
        next =
            '$next${separator()}select=id,task_id,title,student_id,student_name,student_email,file_url,file_type,drive_link,submitted_at,status,feedback,is_late,student_done,done_at';
      }
    }
    if (!hasLimit &&
        (next.startsWith('/users') ||
            next.startsWith('/notifications') ||
            next.startsWith('/task_submissions'))) {
      next = '$next${separator()}limit=$defaultPageSize';
    }
    return next;
  }
}
