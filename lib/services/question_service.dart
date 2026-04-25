import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import 'api_base.dart';

class QuestionService extends ApiServiceBase {
  QuestionService._();
  static final QuestionService instance = QuestionService._();

  Future<List<Question>> getQuestions({String? mentorId, String? studentId}) async {
    final queryParams = <String, String>{};
    if (mentorId != null) queryParams['mentor_id'] = mentorId;
    if (studentId != null) queryParams['student_id'] = studentId;

    final uri = buildUri('/questions').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((q) => Question.fromJson(q as Map<String, dynamic>)).toList();
      }
      throw ApiException('Unexpected questions response format');
    }
    
    throwApiError(response, 'Failed to load questions');
  }

  Future<Question> createQuestion({
    required String courseId,
    required String moduleId,
    required String lessonId,
    required String mentorId,
    required String title,
    required String description,
    String? attachmentUrl,
  }) async {
    final uri = buildUri('/questions');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'course_id': courseId,
        'module_id': moduleId,
        'lesson_id': lessonId,
        'mentor_id': mentorId,
        'title': title,
        'description': description,
        'attachment_url': attachmentUrl,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      return Question.fromJson(decoded as Map<String, dynamic>);
    }
    throwApiError(response, 'Failed to create question');
  }

  Future<Question> replyToQuestion({
    required String questionId,
    required String reply,
  }) async {
    final uri = buildUri('/questions/$questionId/reply');
    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'reply': reply,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      return Question.fromJson(decoded as Map<String, dynamic>);
    }
    throwApiError(response, 'Failed to reply to question');
  }
}
