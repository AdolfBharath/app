import 'package:flutter/foundation.dart';

import '../../../../models/batch.dart';
import '../../../../models/course.dart';
import '../../../../models/user.dart';
import '../../../../services/api_service.dart';

import '../../../../models/question.dart';
import '../../../../models/task_submission.dart';
import '../../../../services/task_service.dart';

class MentorProject {
  MentorProject({
    required this.id,
    required this.studentName,
    required this.title,
    required this.status,
    this.isTask = false,
    this.taskId,
    this.batchId,
  });

  final String id;
  final String studentName;
  final String title;
  final String status;
  final bool isTask;
  final String? taskId;
  final String? batchId;
}

class MentorNotification {
  MentorNotification({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
    required this.read,
    this.type = 'system',
    this.priority = 'low',
    this.actionUrl,
    this.imageUrl,
  });

  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;
  final bool read;
  final String type;
  final String priority;
  final String? actionUrl;
  final String? imageUrl;
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

  static const Duration _notificationTtl = Duration(days: 7);

  bool _isExpired(MentorNotification notification) {
    return DateTime.now().difference(notification.timestamp) > _notificationTtl;
  }

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

      if (currentUser.courseIds.isNotEmpty) {
        try {
          final assigned = currentUser.courseIds.toSet();
          final sourceCourses = resolvedCourses.isNotEmpty
              ? resolvedCourses
              : await api.getCourses();
          resolvedCourses = sourceCourses
              .where((course) => assigned.contains(course.id))
              .toList(growable: false);
        } catch (_) {
          // Keep whatever was loaded above.
        }
      }

      try {
        resolvedBatches = await api.getMentorBatches();
        if (currentUser.courseIds.isNotEmpty) {
          final assigned = currentUser.courseIds.toSet();
          resolvedBatches = resolvedBatches
              .where(
                (batch) =>
                    batch.mentorId == currentUser.id ||
                    assigned.contains(batch.courseId),
              )
              .toList(growable: false);
        } else {
          resolvedBatches = resolvedBatches
              .where((batch) => batch.mentorId == currentUser.id)
              .toList(growable: false);
        }
      } catch (_) {
        resolvedBatches = const [];
      }

      try {
        resolvedProjects = await api.getMentorProjects();
      } catch (_) {
        resolvedProjects = const [];
      }

      try {
        await api.deleteExpiredNotifications().catchError((_) {});
        resolvedNotifications = await api.getMentorNotifications();
      } catch (_) {
        resolvedNotifications = const [];
      }

      // Fetch Task Submissions and merge them as projects
      List<TaskSubmission> taskSubmissions = [];
      try {
        final batchIds = resolvedBatches.map((b) => b.id).toList();
        taskSubmissions = await TaskService.instance.getAllMentorSubmissions(
          batchIds,
        );
      } catch (_) {
        taskSubmissions = [];
      }

      _courses
        ..clear()
        ..addAll(resolvedCourses);
      _batches
        ..clear()
        ..addAll(resolvedBatches);

      try {
        final fetchedQuestions = await api.getQuestions(
          mentorId: currentUser.id,
        );
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
        )
        ..addAll(
          taskSubmissions.map((sub) {
            return MentorProject(
              id: sub.id,
              studentName: sub.studentName ?? 'Student',
              title: sub.title ?? "Submission",
              status: sub.status,
              isTask: true,
              taskId: sub.taskId,
              batchId: sub.batchId,
            );
          }),
        );

      _notifications
        ..clear()
        ..addAll(
          resolvedNotifications
              .where((map) {
                final type = (map['type'] ?? '').toString().toLowerCase();
                final target = (map['target_group'] ?? '')
                    .toString()
                    .toLowerCase();
                if (type == 'admin') return false;
                return target.isEmpty || target == 'mentor' || target == 'both';
              })
              .map((map) {
                return MentorNotification(
                  id: (map['id'] ?? '').toString(),
                  sender: (map['sender'] ?? 'System') as String,
                  message: (map['message'] ?? '') as String,
                  timestamp:
                      DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                  read: (map['read'] as bool?) ?? false,
                  type: map['type']?.toString() ?? 'system',
                  priority: map['priority']?.toString() ?? 'low',
                  actionUrl: map['action_url']?.toString(),
                  imageUrl: map['image_url']?.toString(),
                );
              })
              .where((notification) => !_isExpired(notification)),
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

  Future<void> markNotificationRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;
    if (_notifications[index].read) return;

    _notifications[index] = MentorNotification(
      id: _notifications[index].id,
      sender: _notifications[index].sender,
      message: _notifications[index].message,
      timestamp: _notifications[index].timestamp,
      read: true,
      type: _notifications[index].type,
      priority: _notifications[index].priority,
      actionUrl: _notifications[index].actionUrl,
      imageUrl: _notifications[index].imageUrl,
    );
    notifyListeners();

    try {
      await ApiService.instance.markNotificationRead(notificationId);
    } catch (_) {
      // Keep UI responsive even if backend update fails.
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;

    final removed = _notifications.removeAt(index);
    notifyListeners();

    try {
      await ApiService.instance.deleteNotification(notificationId);
    } catch (_) {
      _notifications.insert(index, removed);
      notifyListeners();
    }
  }
}
