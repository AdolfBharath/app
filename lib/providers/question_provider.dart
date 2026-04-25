import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/api_service.dart';

class QuestionProvider with ChangeNotifier {
  List<Question> _studentQuestions = [];
  bool _isLoading = false;

  List<Question> get studentQuestions => _studentQuestions;
  bool get isLoading => _isLoading;

  Future<void> fetchStudentQuestions(String studentId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _studentQuestions = await ApiService.instance.getQuestions(studentId: studentId);
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> askQuestion({
    required String courseId,
    required String moduleId,
    required String lessonId,
    required String mentorId,
    required String title,
    required String description,
    String? attachmentUrl,
  }) async {
    try {
      final newQuestion = await ApiService.instance.createQuestion(
        courseId: courseId,
        moduleId: moduleId,
        lessonId: lessonId,
        mentorId: mentorId,
        title: title,
        description: description,
        attachmentUrl: attachmentUrl,
      );
      _studentQuestions.insert(0, newQuestion);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error asking question: $e');
      return false;
    }
  }
}
