import 'package:flutter/foundation.dart';

import '../../../../models/batch.dart';
import '../../../../models/course.dart';
import '../../../../models/user.dart';
import '../../../../services/api_service.dart';

import '../../../../models/question.dart';

class MentorProject {
  MentorProject({
    required this.id,
    required this.studentName,
    required this.title,
    required this.status,
  });

  final String id;
  final String studentName;
  final String title;
  final String status;
}

class MentorNotification {
  MentorNotification({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;
}

class MentorProvider extends ChangeNotifier {
  MentorProvider({required AppUser? currentUser}) : _currentUser = currentUser;

  AppUser? _currentUser;

  final List<Course> _courses = [];
  final List<Batch> _batches = [];
  final List<Question> _questions = [];
  final List<MentorProject> _projects = [];
  final List<MentorNotification> _notifications = [];

  bool _isLoading = false;

  void updateCurrentUser(AppUser? user) {
    _currentUser = user;
  }

  List<Course> get courses => List.unmodifiable(_courses);
  List<Batch> get batches => List.unmodifiable(_batches);
  List<Question> get questions => List.unmodifiable(_questions);
  List<MentorProject> get projects => List.unmodifiable(_projects);
  List<MentorNotification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    final currentUser = _currentUser;
    if (currentUser == null || currentUser.role != UserRole.mentor) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService.instance;
      List<Course> resolvedCourses = const [];
      List<Batch> resolvedBatches = const [];
      List<Map<String, dynamic>> resolvedProjects = const [];
      List<Map<String, dynamic>> resolvedNotifications = const [];

      try {
        resolvedCourses = await api.getMentorCourses();
      } catch (_) {
        resolvedCourses = const [];
      }

      if (resolvedCourses.isEmpty && currentUser.courseIds.isNotEmpty) {
        try {
          final allCourses = await api.getCourses();
          final assigned = currentUser.courseIds.toSet();
          resolvedCourses = allCourses
              .where((course) => assigned.contains(course.id))
              .toList(growable: false);
        } catch (_) {
          // Keep whatever was loaded above.
        }
      }

      try {
        resolvedBatches = await api.getMentorBatches();
      } catch (_) {
        resolvedBatches = const [];
      }

      try {
        resolvedProjects = await api.getMentorProjects();
      } catch (_) {
        resolvedProjects = const [];
      }

      try {
        resolvedNotifications = await api.getMentorNotifications();
      } catch (_) {
        resolvedNotifications = const [];
      }

      _courses
        ..clear()
        ..addAll(resolvedCourses);
      _batches
        ..clear()
        ..addAll(resolvedBatches);

      try {
        final fetchedQuestions = await api.getQuestions(mentorId: currentUser.id);
        _questions
          ..clear()
          ..addAll(fetchedQuestions);
      } catch (_) {
        _questions.clear();
      }

      _projects
        ..clear()
        ..addAll(
          resolvedProjects.map((map) {
            return MentorProject(
              id: (map['id'] ?? '').toString(),
              studentName: (map['student_name'] ?? 'Student') as String,
              title: (map['title'] ?? '') as String,
              status: (map['status'] ?? 'Pending') as String,
            );
          }),
        );

      _notifications
        ..clear()
        ..addAll(
          resolvedNotifications.map((map) {
            return MentorNotification(
              id: (map['id'] ?? '').toString(),
              sender: (map['sender'] ?? 'System') as String,
              message: (map['message'] ?? '') as String,
              timestamp:
                  DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            );
          }),
        );
    } catch (_) {
      // Fail silently and keep whatever data we have.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> replyToQuestion(String questionId, String reply) async {
    try {
      final updated = await ApiService.instance.replyToQuestion(
        questionId: questionId,
        reply: reply,
      );
      final index = _questions.indexWhere((q) => q.id == questionId);
      if (index != -1) {
        _questions[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error replying to question: $e');
      return false;
    }
  }
}

