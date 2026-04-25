import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/course.dart';
import 'api_base.dart';

/// Domain service for all course-related API operations.
class CourseService extends ApiServiceBase {
  CourseService._();
  static final CourseService instance = CourseService._();

  // ---------------------------------------------------------------------------
  // Shared course parser
  // ---------------------------------------------------------------------------

  Course parseCourse(Map<String, dynamic> map) {
    final String id = (map['id'] ?? '').toString();
    final String title = (map['title'] ?? '') as String;
    final String description = (map['description'] ?? '') as String;
    final String category = (map['category'] ?? map['course_category'] ?? '')
      .toString();
    final String duration = (map['duration'] ?? '')
      .toString();
    final String moduleType = (map['module_type'] ?? map['moduleType'] ?? 'Self-paced').toString();
    final String instructorName =
        (map['instructor_name'] ?? 'Academy Mentor') as String;
    final String thumbnailUrl =
        (map['thumbnail_url'] ?? map['imageUrl'] ?? '') as String;

    final String status =
      (map['status'] ?? map['course_status'] ?? '').toString();

    final dynamic rawCreatedByAdmin = map['created_by_admin'] ??
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
        map['quiz_coin_reward'] ?? map['quizCoinReward'] ?? 0;
      final int quizCoinReward = rawQuizCoinReward is num
        ? rawQuizCoinReward.toInt()
        : int.tryParse(rawQuizCoinReward.toString()) ?? 0;

      final dynamic rawQuizPassScore =
        map['quiz_pass_score'] ?? map['quizPassScore'] ?? 0;
      final int quizPassScore = rawQuizPassScore is num
        ? rawQuizPassScore.toInt()
        : int.tryParse(rawQuizPassScore.toString()) ?? 0;

    final dynamic rawFeatured =
        map['is_featured'] ?? map['isFeatured'] ?? map['featured'];
    final bool isFeatured =
        rawFeatured is bool ? rawFeatured : rawFeatured == 1;

    final dynamic rawMyCourse =
        map['is_my_course'] ?? map['isMyCourse'] ?? map['myCourse'];
    final bool isMyCourse =
        rawMyCourse is bool ? rawMyCourse : rawMyCourse == 1;

    final dynamic rawDifficulty = map['difficulty'] ??
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

    final dynamic rawModules = map['modules'];
    final List<CourseModule> modules;
    if (rawModules is List) {
      // Check if the backend already provides a nested structure
      final isNested = rawModules.isNotEmpty &&
          rawModules.first is Map &&
          (rawModules.first as Map).containsKey('lessons');

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
              videoDriveLink: (l['videoDriveLink'] ?? l['video_drive_link'] ?? '').toString(),
              transcript: (l['transcript'] ?? '').toString(),
              duration: (l['duration'] ?? '').toString(),
              orderIndex: (l['orderIndex'] ?? l['order_index'] ?? lIdx).toInt(),
              isCompleted: (l['isCompleted'] ?? l['is_completed'] ?? false) as bool,
            );
          }).toList();

          return CourseModule(
            id: (m['id'] ?? '').toString(),
            title: (m['title'] ?? '').toString(),
            description: (m['description'] ?? m['moduleDescription'] ?? '').toString(),
            orderIndex: (m['orderIndex'] ?? m['order_index'] ?? m['moduleNumber'] ?? index).toInt(),
            lessons: lessons,
            coinReward: (m['coinReward'] ?? m['coin_reward'] ?? 0).toInt(),
            studyMaterials: _parseStudyMaterials(m['studyMaterials'] ?? m['study_materials']),
            quizQuestions: _parseQuizQuestions(m['quizQuestions'] ?? m['quiz_questions']),
          );
        }).toList();
      } else {
        // Flat structure fallback: group by moduleNumber
        final groupedMap = <int, List<Map<String, dynamic>>>{};
        for (final m in rawModules) {
          if (m is! Map) continue;
          final mm = Map<String, dynamic>.from(m);
          final modNum = (mm['moduleNumber'] ?? mm['module_number'] ?? 1).toInt();
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
              videoDriveLink: (l['videoDriveLink'] ?? l['video_drive_link'] ?? '').toString(),
              transcript: (l['transcript'] ?? '').toString(),
              duration: (l['duration'] ?? '').toString(),
              orderIndex: (l['orderIndex'] ?? l['order_index'] ?? lIdx).toInt(),
            );
          }).toList();

          return CourseModule(
            id: 'mod_$modNum',
            title: (first['title'] ?? 'Module $modNum').toString(),
            description: (first['moduleDescription'] ?? '').toString(),
            orderIndex: modNum,
            lessons: lessons,
            coinReward: (first['coinReward'] ?? first['coin_reward'] ?? 0).toInt(),
            studyMaterials: _parseStudyMaterials(first['studyMaterials'] ?? first['study_materials']),
            quizQuestions: _parseQuizQuestions(first['quizQuestions'] ?? first['quiz_questions']),
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
      mentorId: (map['mentor_id'] ?? map['mentorId'])?.toString(),
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
              driveLink: (mm['driveLink'] ?? mm['drive_link'] ?? '').toString(),
              fileName: (mm['fileName'] ?? mm['file_name'] ?? '').toString(),
              fileType: (mm['fileType'] ?? mm['file_type'] ?? '').toString(),
            ),
          );
        }
      }
    }
    return list;
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
              correctAnswer: (qq['correctAnswer'] ?? qq['correct_answer'] ?? '').toString(),
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
    final uri = buildUri('/courses');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Course>((dynamic item) =>
                parseCourse(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected courses response format');
    }

    throwApiError(response, 'Failed to load courses');
  }

  /// Fetch courses assigned to the currently authenticated mentor.
  Future<List<Course>> getMentorCourses() async {
    final uri = buildUri('/mentor/courses');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Course>((dynamic item) =>
                parseCourse(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected mentor courses response format');
    }

    throwApiError(response, 'Failed to load mentor courses');
  }

  /// Fetch all courses with status metadata (admin review screen).
  Future<List<Course>> getCoursesWithStatus() async {
    final uri = buildUri('/courses?includeStatus=true');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Course>((dynamic item) =>
                parseCourse(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected courses response format');
    }

    throwApiError(response, 'Failed to load courses with status');
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Enroll the currently authenticated student into a course.
  Future<void> enrollInCourse(String courseId) async {
    final uri = buildUri('/courses/$courseId/enroll');
    final response = await http.post(uri, headers: await buildAuthHeaders());

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
    double price = 0.0,
    bool isFeatured = false,
    bool isMyCourse = false,
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
      body['thumbnailUrl'] = thumbnailUrl;
    }
    if (mentorId != null && mentorId.isNotEmpty) body['mentor_id'] = mentorId;
    body['isFeatured'] = isFeatured;
    body['isMyCourse'] = isMyCourse;

    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to create course');
  }

  /// Update course feature / my-course flags only.
  Future<bool> updateCourseFlags(
    String id, {
    bool? isFeatured,
    bool? isMyCourse,
  }) async {
    final uri = buildUri('/courses/$id');
    final Map<String, dynamic> body = {};
    if (isFeatured != null) body['isFeatured'] = isFeatured;
    if (isMyCourse != null) body['isMyCourse'] = isMyCourse;
    if (body.isEmpty) return false;

    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
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
  }) async {
    final uri = buildUri('/courses/$id');
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
    };
    // Only send mentor_id when it is explicitly provided (non-null).
    // Sending null would be treated as defined by JSON, potentially
    // clearing the existing mentor assignment on the server.
    if (mentorId != null && mentorId.isNotEmpty) {
      body['mentor_id'] = mentorId;
    }

    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(body),
    );

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to update course details');
  }

  /// Delete a course by id.
  Future<bool> deleteCourse(String id) async {
    final uri = buildUri('/courses/$id');
    final response = await http.delete(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) return true;
    throwApiError(response, 'Failed to delete course');
  }

  Future<Map<String, dynamic>> getCourseProgress(String courseId) async {
    final uri = buildUri('/courses/$courseId/progress');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException('Unexpected course progress response format');
    }

    throwApiError(response, 'Failed to load course progress');
  }

  Future<Map<String, dynamic>> completeLesson({
    required String courseId,
    required int moduleNumber,
    required String lessonKey,
  }) async {
    final uri = buildUri('/courses/$courseId/lessons/complete');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'module_number': moduleNumber,
        'lesson_key': lessonKey,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException('Unexpected lesson completion response format');
    }

    throwApiError(response, 'Failed to complete lesson');
  }

  Future<Map<String, dynamic>> completeQuiz({
    required String courseId,
    required int score,
    required int total,
  }) async {
    final uri = buildUri('/courses/$courseId/quiz/complete');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'score': score,
        'total': total,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException('Unexpected quiz completion response format');
    }

    throwApiError(response, 'Failed to complete quiz');
  }
}
