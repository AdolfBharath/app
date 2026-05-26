import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/course.dart';
import '../../../../models/shop_item.dart';
import '../../../../services/api_service.dart';
import '../../../../services/shop_service.dart';

class StudentNotification {
  StudentNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.read,
    this.type = 'system',
    this.priority = 'low',
    this.actionUrl,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;
  final String type;
  final String priority;
  final String? actionUrl;
  final String? imageUrl;

  StudentNotification copyWith({bool? read}) {
    return StudentNotification(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      read: read ?? this.read,
      type: type,
      priority: priority,
      actionUrl: actionUrl,
      imageUrl: imageUrl,
    );
  }
}

class StudentProvider extends ChangeNotifier {
  static const _guestUserKey = 'guest';
  static const _genderKeyPrefix = 'student_gender';
  static const _profileImageKeyPrefix = 'student_profile_image_base64';
  static const _purchasedItemIdsKeyPrefix = 'student_purchased_item_ids';

  String? _activeUserId;
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
  final List<ShopItem> _purchasedItems = [];
  final Set<String> _cachedPurchasedIds = {};

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
        final streakStartDate = todayNormalized.subtract(
          Duration(days: _streakCount - 1),
        );
        if (!dayNormalized.isBefore(streakStartDate) &&
            !dayNormalized.isAfter(todayNormalized)) {
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
  List<ShopItem> get purchasedItems => List.unmodifiable(_purchasedItems);
  bool isItemPurchased(String itemId) =>
      _purchasedItems.any((item) => item.id == itemId) ||
      _cachedPurchasedIds.contains(itemId);
  bool get isLoading => _isLoading;

  double getCourseProgress(String courseId) => _courseProgress[courseId] ?? 0.0;
  List<String> getCompletedLessons(String courseId) =>
      _completedLessonKeys[courseId] ?? [];
  bool isProgressLoading(String courseId) =>
      _isLoadingProgress[courseId] ?? false;

  String get _storageUserKey {
    final id = _activeUserId?.trim();
    return id == null || id.isEmpty ? _guestUserKey : id;
  }

  String get _genderKey => '${_genderKeyPrefix}_$_storageUserKey';
  String get _profileImageKey => '${_profileImageKeyPrefix}_$_storageUserKey';
  String get _purchasedItemIdsKey =>
      '${_purchasedItemIdsKeyPrefix}_$_storageUserKey';

  void _resetUserScopedState() {
    _gender = 'male';
    _profileImageBytes = null;
    _purchasedItems.clear();
    _cachedPurchasedIds.clear();
  }

  Future<void> setActiveUser(String? userId) async {
    final normalized = userId?.trim();
    final nextUserId =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (_activeUserId == nextUserId) return;

    _activeUserId = nextUserId;
    _resetUserScopedState();
    await _loadFromStorage();
    notifyListeners();
  }

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

    // Load offline purchased items
    final savedIds = prefs.getStringList(_purchasedItemIdsKey);
    if (savedIds != null && savedIds.isNotEmpty) {
      _cachedPurchasedIds.addAll(savedIds);
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, _gender);
    if (_profileImageBytes != null) {
      await prefs.setString(
        _profileImageKey,
        base64Encode(_profileImageBytes!),
      );
    } else {
      await prefs.remove(_profileImageKey);
    }
  }

  Future<void> _savePurchasedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _purchasedItems.map((i) => i.id).toSet().toList();
    // Merge with cached ids
    final allIds = {..._cachedPurchasedIds, ...ids}.toList();
    await prefs.setStringList(_purchasedItemIdsKey, allIds);
  }

  /// Syncs the local student state with the user profile fetched from the backend.
  /// The backend is the single source of truth for coins, streaks, and activity.
  void syncWithUser(dynamic user) {
    if (user == null) return;
    final userId = user.id?.toString();
    if (userId != null && userId.isNotEmpty && userId != _activeUserId) {
      unawaited(setActiveUser(userId));
    }

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

  Future<void> addPurchasedItemOffline(ShopItem item) async {
    if (!_cachedPurchasedIds.contains(item.id)) {
      _cachedPurchasedIds.add(item.id);
      if (!_purchasedItems.any((i) => i.id == item.id)) {
        _purchasedItems.add(item);
      }
      await _savePurchasedItems();
      notifyListeners();
    }
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
          courses.where((course) => assignedCourseIds.contains(course.id)),
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
      final completed = data['completed_lessons'] as List? ?? [];
      _completedLessonKeys[courseId] = completed
          .map((e) => e.toString())
          .toList();

      Course? course;
      for (final item in _allCourses) {
        if (item.id == courseId) {
          course = item;
          break;
        }
      }
      final totalLessons =
          course?.modules.fold<int>(
            0,
            (sum, module) => sum + module.lessons.length,
          ) ??
          0;
      _courseProgress[courseId] = totalLessons > 0
          ? (completed.length / totalLessons).clamp(0.0, 1.0)
          : 0.0;
    } catch (e) {
      if (kDebugMode) print('Fetch progress failed for $courseId: $e');
    } finally {
      _isLoadingProgress[courseId] = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications — 7-day auto-expiry
  // ---------------------------------------------------------------------------

  /// Messages/notifications that are more than 7 days old are
  /// automatically hidden (and deleted from the backend when possible).
  static const Duration _notificationTtl = Duration(days: 7);

  bool _isExpired(StudentNotification n) {
    return DateTime.now().difference(n.timestamp) > _notificationTtl;
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService.instance;
      await api.deleteExpiredNotifications().catchError((_) {});
      final raw = await api.getMentorNotifications();

      final parsed = raw
          .where((map) {
            final type = (map['type'] ?? '').toString().toLowerCase();
            final target = (map['target_group'] ?? '').toString().toLowerCase();
            if (type == 'reward') return false;
            if (type == 'admin') return false;
            return target.isEmpty || target == 'student' || target == 'both';
          })
          .map((map) {
            final createdAt = DateTime.tryParse(
              map['created_at']?.toString() ?? '',
            );
            return StudentNotification(
              id: (map['id'] ?? '').toString(),
              title: (map['title'] ?? 'Notification') as String,
              message: (map['message'] ?? '') as String,
              timestamp: createdAt ?? DateTime.now(),
              read: (map['read'] as bool?) ?? false,
              type: map['type']?.toString() ?? 'system',
              priority: map['priority']?.toString() ?? 'low',
              actionUrl: map['action_url']?.toString(),
              imageUrl: map['image_url']?.toString(),
            );
          })
          .toList();

      // Auto-delete expired (read + >7 days old) notifications from the backend.
      final expired = parsed.where(_isExpired).toList();
      for (final n in expired) {
        _deleteNotificationFromBackend(n.id); // fire-and-forget
      }

      _notifications
        ..clear()
        ..addAll(parsed.where((n) => !_isExpired(n)));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;
    final current = _notifications[index];
    if (current.read) return;

    _notifications[index] = current.copyWith(read: true);
    notifyListeners();

    try {
      await ApiService.instance.markNotificationRead(notificationId);
    } catch (_) {
      // Keep UI responsive even if backend update fails.
    }
  }

  /// Immediately removes a notification from local state and deletes it on
  /// the backend (best-effort; UI stays consistent even if the API call fails).
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
    _deleteNotificationFromBackend(notificationId);
  }

  /// Fire-and-forget backend delete; does not surface errors to the UI.
  void _deleteNotificationFromBackend(String notificationId) {
    ApiService.instance
        .deleteNotification(notificationId)
        .catchError((_) => false);
  }

  Future<void> fetchPurchasedItems(String userId) async {
    await setActiveUser(userId);
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch all shop items to cross-reference
      final allShopItems = await ShopService.instance.fetchShopItems();
      if (kDebugMode) print('Shop items fetched: ${allShopItems.length}');

      // 2. Fetch purchase logs from the notifications table (filtered by type=reward)
      final api = ApiService.instance;
      final logs = await api.getJsonList(
        '/notifications?sender_id=eq.$userId&type=eq.reward',
      );
      if (kDebugMode) print('Purchase logs fetched: ${logs.length}');

      _purchasedItems.clear();

      for (final log in logs) {
        final itemId = log['message']?.toString();
        if (kDebugMode) print('Checking item ID from log: $itemId');
        if (itemId != null) {
          // Find the item details from our shop items list
          try {
            final item = allShopItems.firstWhere((i) => i.id == itemId);
            _purchasedItems.add(item);
            _cachedPurchasedIds.add(item.id);
            if (kDebugMode) print('Added item to purchased: ${item.name}');
          } catch (e) {
            if (kDebugMode) print('Item not found in shop list: $itemId');
          }
        }
      }

      // 3. Fallback: Add items from offline cache that might have failed to insert into notifications
      for (final cachedId in _cachedPurchasedIds) {
        if (!_purchasedItems.any((i) => i.id == cachedId)) {
          try {
            final item = allShopItems.firstWhere((i) => i.id == cachedId);
            _purchasedItems.add(item);
            if (kDebugMode) {
              print('Added offline item to purchased: ${item.name}');
            }
          } catch (_) {}
        }
      }

      await _savePurchasedItems();
      if (kDebugMode) {
        print('Total purchased items loaded: ${_purchasedItems.length}');
      }
    } catch (e) {
      if (kDebugMode) print('Fetch purchased items failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
