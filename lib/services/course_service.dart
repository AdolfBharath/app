import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/course.dart';
import '../utils/supabase_config.dart';
import 'api_base.dart';
import 'notification_service.dart';
import 'token_service.dart';

/// Domain service for all course-related API operations.
class CourseService extends ApiServiceBase {
  CourseService._();
  static final CourseService instance = CourseService._();

  static const _courseSelect =
      'id,title,description,category,duration,module_type,instructor_name,thumbnail_url,google_form_url,status,created_by_admin,rating,price,quiz_coin_reward,quiz_pass_score,is_featured,is_my_course,difficulty,modules,mentor_id';
  static const _courseSummarySelect =
      _courseSelect;
  static const _progressSelect =
      'completed_lessons,completed_modules,rewarded_modules,module_quiz_state,quiz_completed,quiz_score,quiz_attempts,quiz_failed_attempts,quiz_locked,quiz_rewatch_required,quiz_last_score,quiz_last_total,quiz_best_score';

  Future<http.Response> _callAdminProxy(
    String path,
    String method, [
    dynamic body,
  ]) async {
    final uri = Uri.parse('${SupabaseConfig.adminProxyUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    switch (method.toUpperCase()) {
      case 'POST':
        return http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      case 'PATCH':
        return http
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      case 'DELETE':
        return http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 12));
      default:
        throw ApiException('Unsupported proxy method: $method');
    }
  }

  // ---------------------------------------------------------------------------
  // Shared course parser
  // ---------------------------------------------------------------------------

  Course parseCourse(Map<String, dynamic> map) {
    final String id = (map['id'] ?? '').toString();
    final String title = (map['title'] ?? '') as String;
    final String description = (map['description'] ?? '') as String;
    final String category = (map['category'] ?? map['course_category'] ?? '')
        .toString();
    final String duration = (map['duration'] ?? '').toString();
    final String moduleType =
        (map['module_type'] ?? map['module_type'] ?? 'Self-paced').toString();
    final String instructorName =
        (map['instructor_name'] ?? 'Academy Mentor') as String;
    final String thumbnailUrl =
        (map['thumbnail_url'] ?? map['image_url'] ?? '') as String;
    final String googleFormUrl =
        (map['google_form_url'] ?? map['purchase_form_url'] ?? '').toString();

    final String status = (map['status'] ?? map['course_status'] ?? '')
        .toString();

    final dynamic rawCreatedByAdmin =
        map['created_by_admin'] ??
        map['createdByAdmin'] ??
        map['is_admin_created'] ??
        map['admin_created'];
    final bool createdByAdmin = rawCreatedByAdmin is bool
        ? rawCreatedByAdmin
        : rawCreatedByAdmin == 1 ||
              rawCreatedByAdmin == '1' ||
              rawCreatedByAdmin?.toString().toLowerCase() == 'true';

    final dynamic rawRating = map['rating'];
    double rating;
    if (rawRating is num) {
      rating = rawRating.toDouble();
    } else if (rawRating is String) {
      rating = double.tryParse(rawRating) ?? 4.5;
    } else {
      rating = 4.5;
    }

    final dynamic rawPrice = map['price'];
    double price;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String) {
      price = double.tryParse(rawPrice) ?? 0.0;
    } else {
      price = 0.0;
    }

    final dynamic rawQuizCoinReward =
        map['quiz_coin_reward'] ?? map['quiz_coin_reward'] ?? 0;
    final int quizCoinReward = rawQuizCoinReward is num
        ? rawQuizCoinReward.toInt()
        : int.tryParse(rawQuizCoinReward.toString()) ?? 0;

    final dynamic rawQuizPassScore =
        map['quiz_pass_score'] ?? map['quiz_pass_score'] ?? 0;
    final int quizPassScore = rawQuizPassScore is num
        ? rawQuizPassScore.toInt()
        : int.tryParse(rawQuizPassScore.toString()) ?? 0;

    final dynamic rawFeatured =
        map['is_featured'] ?? map['is_featured'] ?? map['featured'];
    final bool isFeatured = rawFeatured is bool
        ? rawFeatured
        : rawFeatured == 1;

    final dynamic rawMyCourse =
        map['is_my_course'] ?? map['is_my_course'] ?? map['myCourse'];
    final bool isMyCourse = rawMyCourse is bool
        ? rawMyCourse
        : rawMyCourse == 1;

    final dynamic rawDifficulty =
        map['difficulty'] ??
        map['course_difficulty'] ??
        map['level'] ??
        map['course_level'];

    CourseDifficulty difficulty = CourseDifficulty.intermediate;
    if (rawDifficulty is num) {
      if (rawDifficulty.toInt() <= 0) {
        difficulty = CourseDifficulty.beginner;
      } else if (rawDifficulty.toInt() >= 2) {
        difficulty = CourseDifficulty.advanced;
      } else {
        difficulty = CourseDifficulty.intermediate;
      }
    } else if (rawDifficulty is String) {
      final v = rawDifficulty.trim().toLowerCase();
      if (v.contains('begin')) {
        difficulty = CourseDifficulty.beginner;
      } else if (v.contains('adv')) {
        difficulty = CourseDifficulty.advanced;
      } else if (v.contains('inter') || v.contains('mid')) {
        difficulty = CourseDifficulty.intermediate;
      }
    }

    dynamic rawModules = map['modules'];
    if (rawModules is String && rawModules.trim().isNotEmpty) {
      try {
        rawModules = jsonDecode(rawModules);
      } catch (_) {
        rawModules = const [];
      }
    }
    final List<CourseModule> modules;
    if (rawModules is List) {
      // Check if the backend already provides a nested structure
      final isNested =
          rawModules.isNotEmpty &&
          rawModules.first is Map &&
          ((rawModules.first as Map).containsKey('lessons') ||
              !(rawModules.first as Map).containsKey('lessonTitle'));

      if (isNested) {
        modules = rawModules.asMap().entries.map((entry) {
          final index = entry.key;
          final m = Map<String, dynamic>.from(entry.value as Map);

          final rawLessons = m['lessons'] as List? ?? [];
          final lessons = rawLessons.asMap().entries.map((le) {
            final lIdx = le.key;
            final l = Map<String, dynamic>.from(le.value as Map);
            return CourseLesson(
              id: (l['id'] ?? '').toString(),
              title: (l['title'] ?? '').toString(),
              videoDriveLink:
                  (l['videoDriveLink'] ?? l['video_drive_link'] ?? '')
                      .toString(),
              transcript: (l['transcript'] ?? '').toString(),
              duration: (l['duration'] ?? '').toString(),
              orderIndex: _asInt(l['orderIndex'] ?? l['order_index'], lIdx),
              isCompleted:
                  (l['isCompleted'] ?? l['is_completed'] ?? false) as bool,
            );
          }).toList();

          return CourseModule(
            id: (m['id'] ?? '').toString(),
            title: (m['title'] ?? '').toString(),
            description: (m['description'] ?? m['moduleDescription'] ?? '')
                .toString(),
            orderIndex: _asInt(
              m['orderIndex'] ?? m['order_index'] ?? m['moduleNumber'],
              index + 1,
            ),
            lessons: lessons,
            coinReward: _asInt(m['coinReward'] ?? m['coin_reward'], 0),
            studyMaterials: _parseStudyMaterials(
              m['studyMaterials'] ?? m['study_materials'],
            ),
            quizQuestions: _parseQuizQuestions(
              m['quizQuestions'] ?? m['quiz_questions'],
            ),
          );
        }).toList();
      } else {
        // Flat structure fallback: group by moduleNumber
        final groupedMap = <int, List<Map<String, dynamic>>>{};
        for (final m in rawModules) {
          if (m is! Map) continue;
          final mm = Map<String, dynamic>.from(m);
          final modNum = _asInt(
            mm['moduleNumber'] ??
                mm['module_number'] ??
                mm['orderIndex'] ??
                mm['order_index'],
            1,
          );
          groupedMap.putIfAbsent(modNum, () => []).add(mm);
        }

        final sortedModNums = groupedMap.keys.toList()..sort();
        modules = sortedModNums.map((modNum) {
          final items = groupedMap[modNum]!;
          final first = items.first;

          final lessons = items.asMap().entries.map((le) {
            final lIdx = le.key;
            final l = le.value;
            return CourseLesson(
              id: (l['id'] ?? '').toString(),
              title: (l['lessonTitle'] ?? l['title'] ?? '').toString(),
              videoDriveLink:
                  (l['videoDriveLink'] ?? l['video_drive_link'] ?? '')
                      .toString(),
              transcript: (l['transcript'] ?? '').toString(),
              duration: (l['duration'] ?? '').toString(),
              orderIndex: _asInt(l['orderIndex'] ?? l['order_index'], lIdx),
            );
          }).toList();

          return CourseModule(
            id: 'mod_$modNum',
            title: (first['title'] ?? 'Module $modNum').toString(),
            description: (first['moduleDescription'] ?? '').toString(),
            orderIndex: modNum,
            lessons: lessons,
            coinReward: _asInt(first['coinReward'] ?? first['coin_reward'], 0),
            studyMaterials: _parseStudyMaterials(
              first['studyMaterials'] ?? first['study_materials'],
            ),
            quizQuestions: _parseQuizQuestions(
              first['quizQuestions'] ?? first['quiz_questions'],
            ),
          );
        }).toList();
      }
    } else {
      modules = const [];
    }

    return Course(
      id: id,
      title: title,
      description: description,
      category: category,
      duration: duration,
      moduleType: moduleType,
      instructorName: instructorName,
      thumbnailUrl: thumbnailUrl,
      rating: rating,
      price: price,
      difficulty: difficulty,
      modules: modules,
      isFeatured: isFeatured,
      isMyCourse: isMyCourse,
      status: status.isEmpty ? 'Published' : status,
      createdByAdmin: createdByAdmin,
      quizCoinReward: quizCoinReward,
      quizPassScore: quizPassScore,
      googleFormUrl: googleFormUrl,
      mentorId: (map['mentor_id'] ?? map['mentor_id'])?.toString(),
    );
  }

  List<CourseStudyMaterial> _parseStudyMaterials(dynamic raw) {
    final list = <CourseStudyMaterial>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final mm = Map<String, dynamic>.from(item);
          final title = (mm['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          list.add(
            CourseStudyMaterial(
              title: title,
              description: (mm['description'] ?? '').toString(),
              driveLink: (mm['driveLink'] ?? mm['drive_link'] ?? '')
                  .toString(),
              fileName: (mm['fileName'] ?? mm['file_name'] ?? '').toString(),
              fileType: (mm['fileType'] ?? mm['file_type'] ?? '').toString(),
            ),
          );
        }
      }
    }
    return list;
  }

  int _asInt(dynamic raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
    return fallback;
  }

  List<CourseQuizQuestion> _parseQuizQuestions(dynamic raw) {
    final list = <CourseQuizQuestion>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final qq = Map<String, dynamic>.from(item);
          final text = (qq['question'] ?? '').toString().trim();
          if (text.isEmpty) continue;
          list.add(
            CourseQuizQuestion(
              question: text,
              optionA: (qq['optionA'] ?? qq['option_a'] ?? '').toString(),
              optionB: (qq['optionB'] ?? qq['option_b'] ?? '').toString(),
              optionC: (qq['optionC'] ?? qq['option_c'] ?? '').toString(),
              optionD: (qq['optionD'] ?? qq['option_d'] ?? '').toString(),
              correctAnswer: (qq['correctAnswer'] ?? qq['correct_answer'] ?? '')
                  .toString(),
            ),
          );
        }
      }
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetch all courses (public endpoint — no auth required).
  Future<List<Course>> getCourses() async {
    final rows = await getCachedJsonList(
      '/courses?select=$_courseSelect&order=created_at.desc&limit=$defaultPageSize',
      ttl: const Duration(minutes: 10),
      disk: true,
    );
    return rows.map<Course>(parseCourse).toList(growable: false);
  }

  Future<Course?> getCourseById(String courseId) async {
    final normalized = courseId.trim();
    if (normalized.isEmpty) return null;
    final rows = await getJsonList(
      '/courses?id=eq.$normalized&select=$_courseSelect&limit=1',
    );
    if (rows.isEmpty) return null;
    return parseCourse(rows.first);
  }

  /// Fetch courses assigned to the currently authenticated mentor.
  Future<List<Course>> getMentorCourses() async {
    final userId = await TokenService.getToken();
    final filter = userId == null || userId.trim().isEmpty
        ? ''
        : '&mentor_id=eq.${userId.trim()}';
    final rows = await getCachedJsonList(
      '/courses?select=$_courseSelect$filter&order=created_at.desc&limit=$defaultPageSize',
      ttl: const Duration(minutes: 5),
      disk: true,
    );
    return rows.map<Course>(parseCourse).toList(growable: false);
  }

  /// Fetch all courses with status metadata (admin review screen).
  Future<List<Course>> getCoursesWithStatus() async {
    final rows = await getCachedJsonList(
      '/courses?select=$_courseSummarySelect&order=created_at.desc&limit=$defaultPageSize',
      ttl: const Duration(minutes: 5),
      disk: true,
    );
    return rows.map<Course>(parseCourse).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Enroll the currently authenticated student into a course.
  Future<void> enrollInCourse(String courseId) async {
    final userId = await TokenService.getToken();
    if (userId == null) throw Exception('Not logged in');

    // 1. Add to user_courses
    await http.post(
      buildUri('/user_courses'),
      headers: await buildAuthHeaders(),
      body: jsonEncode({'user_id': userId, 'course_id': courseId}),
    );

    // 2. Initialize progress
    final progressUri = buildUri('/student_course_progress');
    final response = await http.post(
      progressUri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'student_id': userId,
        'course_id': courseId,
        'completed_lessons': [],
        'completed_modules': [],
        'rewarded_modules': [],
      }),
    );

    if (isSuccess(response)) return;
    throwApiError(response, 'Failed to enroll in course');
  }

  /// Create a new course.
  Future<bool> createCourse(
    String title,
    String description, {
    String? category,
    String? duration,
    String? thumbnailUrl,
    String? mentorId,
    String? instructorName,
    String? googleFormUrl,
    String? difficulty,
    double? rating,
    double price = 0.0,
    bool isFeatured = false,
    bool isMyCourse = false,
    int quizCoinReward = 0,
    int quizPassScore = 0,
  }) async {
    final uri = buildUri('/courses');
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'price': price,
    };
    if (category != null && category.isNotEmpty) body['category'] = category;
    if (duration != null && duration.isNotEmpty) body['duration'] = duration;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      body['thumbnail_url'] = thumbnailUrl;
    }
    if (mentorId != null && mentorId.isNotEmpty) body['mentor_id'] = mentorId;
    if (instructorName != null && instructorName.isNotEmpty) {
      body['instructor_name'] = instructorName;
    }
    if (googleFormUrl != null && googleFormUrl.isNotEmpty) {
      body['google_form_url'] = googleFormUrl;
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      body['difficulty'] = difficulty;
    }
    if (rating != null) body['rating'] = rating;
    body['quiz_coin_reward'] = quizCoinReward;
    body['quiz_pass_score'] = quizPassScore;
    body['is_featured'] = isFeatured;
    body['is_my_course'] = isMyCourse;

    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final response = await _callAdminProxy('/admin/courses', 'POST', body);
      if (isSuccess(response)) {
        invalidateCache('/courses');
        return true;
      }
      throwApiError(response, 'Failed to create course via proxy');
    }

    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) {
      invalidateCache('/courses');
      return true;
    }
    throwApiError(response, 'Failed to create course');
  }

  /// Update course feature / my-course flags only.
  Future<bool> updateCourseFlags(
    String id, {
    bool? isFeatured,
    bool? isMyCourse,
  }) async {
    final uri = buildUri('/courses?id=eq.$id');
    final Map<String, dynamic> body = {};
    if (isFeatured != null) body['is_featured'] = isFeatured;
    if (isMyCourse != null) body['is_my_course'] = isMyCourse;
    if (body.isEmpty) return false;

    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) {
      invalidateCache('/courses');
      return true;
    }
    throwApiError(response, 'Failed to update course flags');
  }

  /// Update core course details including price.
  Future<bool> updateCourseDetails(
    String id, {
    required String title,
    required String description,
    required String category,
    required String duration,
    String moduleType = 'Self-paced',
    required String instructorName,
    required String thumbnailUrl,
    required String difficulty,
    required double rating,
    List<Map<String, dynamic>> modules = const [],
    double price = 0.0,
    String? mentorId,
    int quizCoinReward = 0,
    int quizPassScore = 0,
    String googleFormUrl = '',
  }) async {
    final uri = buildUri('/courses?id=eq.$id');
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'category': category,
      'duration': duration,
      'module_type': moduleType,
      'instructor_name': instructorName,
      'thumbnail_url': thumbnailUrl,
      'difficulty': difficulty,
      'rating': rating,
      'modules': modules,
      'price': price,
      'quiz_coin_reward': quizCoinReward,
      'quiz_pass_score': quizPassScore,
      'google_form_url': googleFormUrl,
    };
    // Only send mentor_id when it is explicitly provided (non-null).
    // Sending null would be treated as defined by JSON, potentially
    // clearing the existing mentor assignment on the server.
    if (mentorId != null && mentorId.isNotEmpty) {
      body['mentor_id'] = mentorId;
    }

    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final response = await _callAdminProxy(
        '/admin/courses/$id',
        'PATCH',
        body,
      );
      if (isSuccess(response)) {
        invalidateCache('/courses');
        return true;
      }
      throwApiError(response, 'Failed to update course via proxy');
    }

    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) {
      invalidateCache('/courses');
      return true;
    }
    throwApiError(response, 'Failed to update course details');
  }

  /// Delete a course by id.
  Future<int> getCourseEnrollmentCount(String courseId) async {
    final uri = buildUri('/user_courses?course_id=eq.$courseId&select=id');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded.length;
      return 0;
    }

    throwApiError(response, 'Failed to load course enrollments');
  }

  /// Delete a course by id.
  Future<bool> deleteCourse(
    String id, {
    String? courseTitle,
    int? enrollmentCount,
  }) async {
    if (SupabaseConfig.adminProxyUrl.isNotEmpty) {
      final response = await _callAdminProxy('/admin/courses/$id', 'DELETE');
      if (!isSuccess(response)) {
        throwApiError(response, 'Failed to delete course via proxy');
      }
      invalidateCache('/courses');
      return true;
    }

    final count = enrollmentCount ?? await getCourseEnrollmentCount(id);

    final progressUri = buildUri('/student_course_progress?course_id=eq.$id');
    final progressResponse = await http.delete(
      progressUri,
      headers: await buildAuthHeaders(),
    );
    if (!isSuccess(progressResponse)) {
      throwApiError(progressResponse, 'Failed to delete course progress');
    }

    final userCoursesUri = buildUri('/user_courses?course_id=eq.$id');
    final userCoursesResponse = await http.delete(
      userCoursesUri,
      headers: await buildAuthHeaders(),
    );
    if (!isSuccess(userCoursesResponse)) {
      throwApiError(userCoursesResponse, 'Failed to delete course enrollments');
    }

    final uri = buildUri('/courses?id=eq.$id');
    final response = await http.delete(uri, headers: await buildAuthHeaders());

    if (!isSuccess(response)) {
      throwApiError(response, 'Failed to delete course');
    }

    if (count > 0) {
      try {
        final safeTitle = (courseTitle == null || courseTitle.isEmpty)
            ? 'A course'
            : courseTitle;
        await NotificationService.instance.sendAnnouncement(
          title: 'Course removed',
          message:
              '$safeTitle has been removed by the admin. It is no longer available in your courses.',
          targetGroup: 'student',
        );
      } catch (_) {
        // Avoid failing deletion if announcement fails.
      }
    }

    invalidateCache('/courses');
    return true;
  }

  Future<Map<String, dynamic>> getCourseProgress(String courseId) async {
    final userId = await TokenService.getToken();
    if (userId == null) return {};
    final uri = buildUri(
      '/student_course_progress?course_id=eq.$courseId&student_id=eq.$userId&select=$_progressSelect&limit=1',
    );
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      }
      return {
        'completed_lessons': [],
        'completed_modules': [],
        'rewarded_modules': [],
        'module_quiz_state': {},
        'quiz_completed': false,
        'quiz_score': 0,
        'quiz_attempts': 0,
        'quiz_failed_attempts': 0,
        'quiz_locked': false,
        'quiz_rewatch_required': false,
        'quiz_last_score': 0,
        'quiz_last_total': 0,
        'quiz_best_score': 0,
      };
    }

    throwApiError(response, 'Failed to load course progress');
  }

  Future<Map<String, dynamic>> completeLesson({
    required String courseId,
    required int moduleNumber,
    required String lessonKey,
    List<String> moduleLessonKeys = const [],
    int totalLessonCount = 0,
  }) async {
    final userId = await TokenService.getToken();
    if (userId == null) throw Exception('Not logged in');

    final progress = await getCourseProgress(courseId);

    final completedLessons = List<dynamic>.from(
      progress['completed_lessons'] ?? const [],
    );
    if (!completedLessons.contains(lessonKey)) {
      completedLessons.add(lessonKey);
    }

    final completedModules = List<dynamic>.from(
      progress['completed_modules'] ?? const [],
    );
    final moduleCompleted =
        moduleLessonKeys.isNotEmpty &&
        moduleLessonKeys.every(completedLessons.contains);
    if (moduleCompleted && !completedModules.contains(moduleNumber)) {
      completedModules.add(moduleNumber);
    }

    final patchBody = <String, dynamic>{
      'completed_lessons': completedLessons,
      'completed_modules': completedModules,
    };

    final uri = buildUri(
      '/student_course_progress?course_id=eq.$courseId&student_id=eq.$userId',
    );
    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(patchBody),
    );

    if (isSuccess(response)) {
      if (response.body.trim().isNotEmpty) {
        var decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return decoded.first as Map<String, dynamic>;
        }
      }
      final created = await _createProgressRowAfterLesson(
        userId: userId,
        courseId: courseId,
        patchBody: patchBody,
      );
      if (created != null) return created;
      return patchBody;
    }

    throwApiError(response, 'Failed to complete lesson');
  }

  Future<Map<String, dynamic>?> _createProgressRowAfterLesson({
    required String userId,
    required String courseId,
    required Map<String, dynamic> patchBody,
  }) async {
    final body = <String, dynamic>{
      'student_id': userId,
      'course_id': courseId,
      'completed_lessons': patchBody['completed_lessons'] ?? const [],
      'completed_modules': patchBody['completed_modules'] ?? const [],
      'rewarded_modules': const [],
    };
    final response = await http.post(
      buildUri('/student_course_progress'),
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );
    if (!isSuccess(response)) return null;
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      }
    }
    return body;
  }

  Future<Map<String, dynamic>> completeQuiz({
    required String courseId,
    required int score,
    required int total,
    required int passScore,
    String? moduleId,
    int? moduleOrder,
    String? moduleTitle,
  }) async {
    final userId = await TokenService.getToken();
    if (userId == null) throw Exception('Not logged in');

    final passed = score >= passScore;
    final progress = await getCourseProgress(courseId);
    final moduleKey = _moduleQuizKey(moduleId, moduleOrder);
    final moduleStates = _decodeModuleQuizState(progress['module_quiz_state']);
    final existingState = moduleStates[moduleKey] ?? const <String, dynamic>{};
    final currentAttempts = moduleKey == null
        ? (progress['quiz_attempts'] as num?)?.toInt() ?? 0
        : (existingState['attempts'] as num?)?.toInt() ?? 0;
    final currentFailedAttempts = moduleKey == null
        ? (progress['quiz_failed_attempts'] as num?)?.toInt() ?? 0
        : (existingState['failed_attempts'] as num?)?.toInt() ?? 0;
    final nextAttempt = currentAttempts + 1;
    final failedAttempts = passed ? 0 : currentFailedAttempts + 1;
    final locked = moduleKey == null
        ? nextAttempt >= 5
        : (!passed && failedAttempts >= 3);
    final previousBest = moduleKey == null
        ? (progress['quiz_best_score'] as num?)?.toInt() ?? 0
        : (existingState['best_score'] as num?)?.toInt() ?? 0;
    final bestScore = [previousBest, score].reduce((a, b) => a > b ? a : b);
    if (moduleKey != null) {
      moduleStates[moduleKey] = {
        'attempts': nextAttempt,
        'failed_attempts': failedAttempts,
        'locked': locked,
        'rewatch_required': locked,
        'completed': passed,
        'last_score': score,
        'last_total': total,
        'best_score': bestScore,
        'module_id': moduleId,
        'module_order': moduleOrder,
        'module_title': moduleTitle ?? '',
      };
    }

    final attemptBody = <String, dynamic>{
      'student_id': userId,
      'course_id': courseId,
      'score': score,
      'total': total,
      'pass_score': passScore,
      'passed': passed,
      'attempt_number': nextAttempt,
    };
    if (moduleId != null && moduleId.isNotEmpty) {
      attemptBody['module_id'] = moduleId;
    }
    if (moduleOrder != null) {
      attemptBody['module_order'] = moduleOrder;
    }
    if (moduleTitle != null && moduleTitle.isNotEmpty) {
      attemptBody['module_title'] = moduleTitle;
    }

    final attemptResponse = await http.post(
      buildUri('/student_quiz_attempts'),
      headers: await buildAuthHeaders(),
      body: jsonEncode(attemptBody),
    );
    if (!isSuccess(attemptResponse)) {
      throwApiError(attemptResponse, 'Failed to store quiz attempt');
    }

    final uri = buildUri(
      '/student_course_progress?course_id=eq.$courseId&student_id=eq.$userId',
    );
    final progressPatch = moduleKey == null
        ? <String, dynamic>{
            'quiz_completed': passed,
            'quiz_score': score,
            'quiz_attempts': nextAttempt,
            'quiz_failed_attempts': failedAttempts,
            'quiz_locked': locked,
            'quiz_rewatch_required': locked,
            'quiz_last_score': score,
            'quiz_last_total': total,
            'quiz_best_score': bestScore,
            'module_quiz_state': moduleStates,
          }
        : <String, dynamic>{'module_quiz_state': moduleStates};

    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(progressPatch),
    );

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      }
      return {
        'quiz_completed': moduleKey == null
            ? passed
            : progress['quiz_completed'] == true,
        'quiz_score': moduleKey == null ? score : progress['quiz_score'],
        'quiz_attempts': moduleKey == null
            ? nextAttempt
            : progress['quiz_attempts'],
        'quiz_failed_attempts': moduleKey == null
            ? failedAttempts
            : progress['quiz_failed_attempts'],
        'quiz_locked': moduleKey == null ? locked : progress['quiz_locked'],
        'quiz_rewatch_required': moduleKey == null
            ? locked
            : progress['quiz_rewatch_required'],
        'quiz_last_score': moduleKey == null
            ? score
            : progress['quiz_last_score'],
        'quiz_last_total': moduleKey == null
            ? total
            : progress['quiz_last_total'],
        'quiz_best_score': moduleKey == null
            ? bestScore
            : progress['quiz_best_score'],
        'module_quiz_state': moduleStates,
      };
    }

    throwApiError(response, 'Failed to complete quiz');
  }

  Future<Map<String, dynamic>> unlockQuizAfterRewatch({
    required String courseId,
    String? moduleId,
    int? moduleOrder,
  }) async {
    final userId = await TokenService.getToken();
    if (userId == null) throw Exception('Not logged in');

    final progress = await getCourseProgress(courseId);
    final moduleKey = _moduleQuizKey(moduleId, moduleOrder);
    final moduleStates = _decodeModuleQuizState(progress['module_quiz_state']);
    if (moduleKey != null) {
      final existing = moduleStates[moduleKey] ?? const <String, dynamic>{};
      moduleStates[moduleKey] = {
        ...existing,
        'failed_attempts': 0,
        'locked': false,
        'rewatch_required': false,
      };
    }

    final uri = buildUri(
      '/student_course_progress?course_id=eq.$courseId&student_id=eq.$userId',
    );
    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'quiz_failed_attempts': 0,
        'quiz_locked': false,
        'quiz_rewatch_required': false,
        if (moduleKey != null) 'module_quiz_state': moduleStates,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first as Map<String, dynamic>;
      }
      return {
        'quiz_failed_attempts': 0,
        'quiz_locked': false,
        'quiz_rewatch_required': false,
        'module_quiz_state': moduleStates,
      };
    }

    throwApiError(response, 'Failed to unlock quiz');
  }

  Future<Map<String, dynamic>> getStudentQuizSummary(String studentId) async {
    final uri = buildUri(
      '/student_quiz_attempts?student_id=eq.$studentId&select=score,total,passed,created_at',
    );
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return {'attempts': 0, 'best_score': 0, 'average_percent': 0};
      }
      var best = 0;
      var percentSum = 0.0;
      var passedCount = 0;
      for (final item in decoded) {
        if (item is! Map) continue;
        final score = (item['score'] as num?)?.toInt() ?? 0;
        final total = (item['total'] as num?)?.toInt() ?? 0;
        if (score > best) best = score;
        if (total > 0) percentSum += (score / total) * 100;
        if (item['passed'] == true) passedCount++;
      }
      return {
        'attempts': decoded.length,
        'best_score': best,
        'average_percent': decoded.isEmpty ? 0 : (percentSum / decoded.length),
        'passed_count': passedCount,
      };
    }

    throwApiError(response, 'Failed to load quiz summary');
  }

  Future<Map<String, dynamic>> getStudentCourseProgressSummary(
    String studentId,
  ) async {
    final progressRows = await getJsonList(
      '/student_course_progress?student_id=eq.$studentId&select=course_id,completed_lessons,quiz_completed',
    );
    if (progressRows.isEmpty) {
      return {'course_count': 0, 'completed_courses': 0, 'average_percent': 0};
    }

    var completedCourses = 0;
    var percentSum = 0.0;
    for (final progress in progressRows) {
      final courseId = progress['course_id']?.toString() ?? '';
      if (courseId.isEmpty) continue;
      var totalLessons = 0;
      try {
        final courses = await getJsonList('/courses?id=eq.$courseId');
        if (courses.isNotEmpty) {
          final course = parseCourse(courses.first);
          totalLessons = course.modules.fold<int>(
            0,
            (sum, module) => sum + module.lessons.length,
          );
        }
      } catch (_) {}
      final completedLessons =
          ((progress['completed_lessons'] as List?) ?? const []).length;
      final percent = totalLessons == 0
          ? 0.0
          : (completedLessons / totalLessons).clamp(0.0, 1.0);
      percentSum += percent * 100;
      if (percent >= 0.999 || progress['quiz_completed'] == true) {
        completedCourses += 1;
      }
    }

    return {
      'course_count': progressRows.length,
      'completed_courses': completedCourses,
      'average_percent': percentSum / progressRows.length,
    };
  }

  String? _moduleQuizKey(String? moduleId, int? moduleOrder) {
    if (moduleId != null && moduleId.trim().isNotEmpty) {
      return moduleId.trim();
    }
    if (moduleOrder != null) return 'module_$moduleOrder';
    return null;
  }

  Map<String, dynamic> _decodeModuleQuizState(dynamic raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}
