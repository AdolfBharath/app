import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/course.dart';
import '../../../../services/api_service.dart';

class StudentNotification {
  StudentNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.read,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;
}

class StudentProvider extends ChangeNotifier {
  StudentProvider() {
    _storageReady = _loadFromStorage();
  }

  late final Future<void> _storageReady;

  static const _genderKey = 'student_gender';
  static const _profileImageKey = 'student_profile_image_base64';

  int _coins = 0;
  int _streakCount = 0;
  DateTime? _lastLoginDate;
  bool _earnedDailyReward = false;
  String _gender = 'male';
  Uint8List? _profileImageBytes;
  final List<bool> _weeklyStreak = List<bool>.filled(7, false);

  final List<Course> _allCourses = [];
  final List<Course> _enrolledCourses = [];
  final Map<String, double> _courseProgress = {};
  final Map<String, List<String>> _completedLessonKeys = {};
  final List<StudentNotification> _notifications = [];
  final Map<String, bool> _isLoadingProgress = {};

  bool _isLoading = false;

  int get coins => _coins;
  int get streakCount => _streakCount;
  DateTime? get lastLoginDate => _lastLoginDate;
  bool get earnedDailyReward => _earnedDailyReward;
  String get gender => _gender;
  Uint8List? get profileImageBytes => _profileImageBytes;

  List<bool> get weeklyStreak => List<bool>.unmodifiable(_weeklyStreak);

  bool loggedInOnDay(DateTime day) {
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    
    // Find Monday of the current week
    final weekStart = todayNormalized.subtract(
      Duration(days: todayNormalized.weekday - DateTime.monday),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    final dayNormalized = DateTime(day.year, day.month, day.day);
    
    // If the day is in the current week
    if (!dayNormalized.isBefore(weekStart) && !dayNormalized.isAfter(weekEnd)) {
      // 1. Check backend-driven weekly streak first (historical logins in same week)
      final index = dayNormalized.difference(weekStart).inDays;
      if (index >= 0 && index < 7 && _weeklyStreak[index]) {
        return true;
      }
      
      // 2. Fallback: Check if this day is part of the current active streak.
      // If streakCount is 2 and today is Saturday, we should fire Saturday and Friday.
      if (_streakCount > 0) {
        final streakStartDate = todayNormalized.subtract(Duration(days: _streakCount - 1));
        if (!dayNormalized.isBefore(streakStartDate) && !dayNormalized.isAfter(todayNormalized)) {
          return true;
        }
      }
    }
    
    return false;
  }

  List<Course> get allCourses => List.unmodifiable(_allCourses);
  List<Course> get enrolledCourses => List.unmodifiable(_enrolledCourses);
  List<StudentNotification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  double getCourseProgress(String courseId) => _courseProgress[courseId] ?? 0.0;
  List<String> getCompletedLessons(String courseId) =>
      _completedLessonKeys[courseId] ?? [];
  bool isProgressLoading(String courseId) =>
      _isLoadingProgress[courseId] ?? false;

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Profile preferences (UI only)
    _gender = prefs.getString(_genderKey) ?? 'male';
    final base64 = prefs.getString(_profileImageKey);
    if (base64 != null) {
      try {
        _profileImageBytes = base64Decode(base64);
      } catch (_) {
        _profileImageBytes = null;
      }
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, _gender);
    if (_profileImageBytes != null) {
      await prefs.setString(_profileImageKey, base64Encode(_profileImageBytes!));
    } else {
      await prefs.remove(_profileImageKey);
    }
  }

  /// Syncs the local student state with the user profile fetched from the backend.
  /// The backend is the single source of truth for coins, streaks, and activity.
  void syncWithUser(dynamic user) {
    if (user == null) return;
    _coins = user.coins;
    _streakCount = user.streakCount;
    _lastLoginDate = user.lastActiveDate;
    
    // Update weekly streak array (Mon=0, Sun=6)
    if (user.weeklyLogins is List) {
      final list = user.weeklyLogins as List;
      for (int i = 0; i < 7 && i < list.length; i++) {
        _weeklyStreak[i] = list[i] == true;
      }
    }
    notifyListeners();
  }

  void clearDailyRewardFlag() {
    if (_earnedDailyReward) {
      _earnedDailyReward = false;
      notifyListeners();
    }
  }

  Future<void> addCoins(int value) async {
    _coins += value;
    notifyListeners();
  }

  Future<void> setCoins(int value) async {
    _coins = value < 0 ? 0 : value;
    notifyListeners();
  }

  Future<bool> spendCoins(int value) async {
    if (value <= 0) return true;
    if (_coins < value) return false;
    _coins -= value;
    notifyListeners();
    return true;
  }

  Future<void> setGender(String gender) async {
    final normalized = gender.trim().toLowerCase();
    if (normalized != 'male' && normalized != 'female') return;
    if (_gender == normalized) return;
    _gender = normalized;
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> setProfileImageBytes(Uint8List? bytes) async {
    _profileImageBytes = bytes;
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> fetchCourses({List<String> assignedCourseIds = const []}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService.instance;
      final courses = await api.getCourses();
      _allCourses
        ..clear()
        ..addAll(courses);

      _enrolledCourses
        ..clear()
        ..addAll(
          assignedCourseIds.isEmpty
              ? courses.where((course) => course.isMyCourse)
              : courses.where((course) => assignedCourseIds.contains(course.id)),
        );
        
      // Fetch progress for all enrolled courses
      for (final course in _enrolledCourses) {
        fetchProgress(course.id); // Run in background
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEnrollments() async {
    if (_allCourses.isEmpty) {
      await fetchCourses();
    }
  }

  Future<void> fetchProgress(String courseId) async {
    if (_isLoadingProgress[courseId] == true) return;
    
    _isLoadingProgress[courseId] = true;
    notifyListeners();

    try {
      final api = ApiService.instance;
      final data = await api.getCourseProgress(courseId);
      final double progress = (data['progress_percentage'] as num?)?.toDouble() ?? 0.0;
      _courseProgress[courseId] = progress / 100.0;
      
      final completed = data['completed_lessons'] as List? ?? [];
      _completedLessonKeys[courseId] =
          completed.map((e) => e.toString()).toList();
    } catch (e) {
      if (kDebugMode) print('Fetch progress failed for $courseId: $e');
    } finally {
      _isLoadingProgress[courseId] = false;
      notifyListeners();
    }
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService.instance;
      final raw = await api.getMentorNotifications();
      _notifications
        ..clear()
        ..addAll(
          raw.map((map) {
            final createdAt = DateTime.tryParse(
              map['created_at']?.toString() ?? '',
            );
            return StudentNotification(
              id: (map['id'] ?? '').toString(),
              title: (map['title'] ?? 'Notification') as String,
              message: (map['message'] ?? '') as String,
              timestamp: createdAt ?? DateTime.now(),
              read: (map['read'] as bool?) ?? false,
            );
          }),
        );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
