import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import '../utils/supabase_config.dart';
import 'api_base.dart';
import 'token_service.dart';

class QuestionService extends ApiServiceBase {
  QuestionService._();
  static final QuestionService instance = QuestionService._();

  static const _questionSelect =
      'id,student_id,student_name,course_id,course_title,module_id,module_title,lesson_id,lesson_title,mentor_id,title,description,attachment_url,reply,status,created_at';

  Future<List<Question>> getQuestions({String? mentorId, String? studentId}) async {
    final queryParams = <String, String>{};
    if (mentorId != null && mentorId.trim().isNotEmpty) {
      queryParams['mentor_id'] = 'eq.${mentorId.trim()}';
    }
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = 'eq.${studentId.trim()}';
    }
    queryParams['select'] = _questionSelect;
    queryParams['order'] = 'created_at.desc';
    queryParams['limit'] = '$expandedPageSize';

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
    final studentId = await TokenService.getToken();
    if (studentId == null || studentId.trim().isEmpty) {
      throw ApiException('Not logged in');
    }

    final uri = buildUri('/questions');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'student_id': studentId,
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
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      return Question.fromJson(decoded as Map<String, dynamic>);
    }
    throwApiError(response, 'Failed to create question');
  }

  Future<Question> replyToQuestion({
    required String questionId,
    required String reply,
  }) async {
    if (SupabaseConfig.adminProxyUrl.trim().isNotEmpty) {
      final base = SupabaseConfig.adminProxyUrl.endsWith('/')
          ? SupabaseConfig.adminProxyUrl.substring(
              0,
              SupabaseConfig.adminProxyUrl.length - 1,
            )
          : SupabaseConfig.adminProxyUrl;
      final response = await http.patch(
        Uri.parse('$base/admin/questions/$questionId/reply'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'reply': reply}),
      );

      if (isSuccess(response)) {
        final decoded = jsonDecode(response.body);
        return Question.fromJson(decoded as Map<String, dynamic>);
      }
      throwApiError(response, 'Failed to reply to question');
    }

    final uri = SupabaseConfig.useFunctionProxy
        ? buildUri('/questions/$questionId/reply')
        : buildUri('/questions?id=eq.$questionId');
    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'reply': reply,
        if (!SupabaseConfig.useFunctionProxy) 'status': 'replied',
      }),
    );

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      return Question.fromJson(decoded as Map<String, dynamic>);
    }
    throwApiError(response, 'Failed to reply to question');
  }
}
