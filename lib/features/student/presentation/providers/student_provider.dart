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

  static const _coinsKey = 'student_total_coins';
  static const _lastLoginKey = 'student_last_login_date';
  static const _streakKey = 'student_streak_count';
  static const _loginHistoryKey = 'student_login_history_days';
  static const _weeklyStreakKey = 'student_weekly_streak';
  static const _weeklyWeekStartKey = 'student_weekly_streak_week_start';
  static const _genderKey = 'student_gender';
  static const _profileImageKey = 'student_profile_image_base64';

  static const _debugSeedMondayLoginKey = 'student_debug_seed_monday_login_v1';

  int _coins = 0;
  int _streakCount = 0;
  DateTime? _lastLoginDate;
  bool _earnedDailyReward = false;
  String _gender = 'male';
  Uint8List? _profileImageBytes;
  final List<DateTime> _loginHistoryDays = [];

  DateTime? _weeklyWeekStart;
  final List<bool> _weeklyStreak = List<bool>.filled(7, false);

  final List<Course> _allCourses = [];
  final List<Course> _enrolledCourses = [];
  final List<StudentNotification> _notifications = [];

  bool _isLoading = false;

  int get coins => _coins;
  int get streakCount => _streakCount;
  DateTime? get lastLoginDate => _lastLoginDate;
  bool get earnedDailyReward => _earnedDailyReward;
  String get gender => _gender;
  Uint8List? get profileImageBytes => _profileImageBytes;

  List<bool> get weeklyStreak => List<bool>.unmodifiable(_weeklyStreak);
  DateTime? get weeklyWeekStart => _weeklyWeekStart;

  List<DateTime> get loginHistoryDays => List.unmodifiable(_loginHistoryDays);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasLoginForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _loginHistoryDays.any((d) => _isSameDay(d, normalized));
  }

  int _computedStreakFromHistory({DateTime? endDay}) {
    if (_loginHistoryDays.isEmpty) return 0;

    final normalizedEnd = endDay == null
        ? (() {
            final now = DateTime.now();
            return DateTime(now.year, now.month, now.day);
          })()
        : DateTime(endDay.year, endDay.month, endDay.day);

    final unique = <DateTime>{
      for (final d in _loginHistoryDays) DateTime(d.year, d.month, d.day),
    }.toList()
      ..sort((a, b) => a.compareTo(b));

    if (unique.isEmpty) return 0;

    // If user hasn't logged in on endDay, streak is 0.
    if (!unique.any((d) => _isSameDay(d, normalizedEnd))) return 0;

    var streak = 1;
    var cursor = normalizedEnd;
    while (true) {
      final prev = cursor.subtract(const Duration(days: 1));
      final hasPrev = unique.any((d) => _isSameDay(d, prev));
      if (!hasPrev) break;
      streak += 1;
      cursor = prev;
    }
    return streak;
  }

  bool loggedInOnDay(DateTime day) {
    return _hasLoginForDay(day);
  }

  List<Course> get allCourses => List.unmodifiable(_allCourses);
  List<Course> get enrolledCourses => List.unmodifiable(_enrolledCourses);
  List<StudentNotification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt(_coinsKey) ?? 0;
    _streakCount = prefs.getInt(_streakKey) ?? 0;

    final rawGender = prefs.getString(_genderKey);
    if (rawGender != null) {
      final normalized = rawGender.trim().toLowerCase();
      if (normalized == 'male' || normalized == 'female') {
        _gender = normalized;
      }
    }

    final rawProfileImage = prefs.getString(_profileImageKey);
    if (rawProfileImage != null && rawProfileImage.isNotEmpty) {
      try {
        _profileImageBytes = base64Decode(rawProfileImage);
      } catch (_) {
        _profileImageBytes = null;
      }
    }

    final last = prefs.getString(_lastLoginKey);
    if (last != null) {
      _lastLoginDate = DateTime.tryParse(last);
    }

    _loginHistoryDays
      ..clear()
      ..addAll(
        (prefs.getStringList(_loginHistoryKey) ?? const [])
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .map((d) => DateTime(d.year, d.month, d.day)),
      );

    final rawWeekStart = prefs.getString(_weeklyWeekStartKey);
    _weeklyWeekStart = rawWeekStart == null ? null : DateTime.tryParse(rawWeekStart);

    final rawWeekly = prefs.getStringList(_weeklyStreakKey);
    if (rawWeekly != null && rawWeekly.length == 7) {
      for (var i = 0; i < 7; i++) {
        _weeklyStreak[i] = rawWeekly[i] == '1';
      }
    } else {
      for (var i = 0; i < 7; i++) {
        _weeklyStreak[i] = false;
      }
    }

    _pruneLoginHistory();
    _ensureWeeklyStreakFor(DateTime.now());

    // Self-heal: if stored streak is lower than what recent history implies,
    // bump it up (never decreases streak to avoid surprising users).
    final computed = _computedStreakFromHistory(endDay: _lastLoginDate);
    if (computed > _streakCount) {
      _streakCount = computed;
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coinsKey, _coins);
    await prefs.setInt(_streakKey, _streakCount);
    await prefs.setString(_genderKey, _gender);
    if (_profileImageBytes != null && _profileImageBytes!.isNotEmpty) {
      await prefs.setString(_profileImageKey, base64Encode(_profileImageBytes!));
    } else {
      await prefs.remove(_profileImageKey);
    }
    if (_lastLoginDate != null) {
      await prefs.setString(_lastLoginKey, _lastLoginDate!.toIso8601String());
    }

    await prefs.setStringList(
      _loginHistoryKey,
      _loginHistoryDays
          .map((d) => DateTime(d.year, d.month, d.day).toIso8601String())
          .toList(growable: false),
    );

    if (_weeklyWeekStart != null) {
      await prefs.setString(
        _weeklyWeekStartKey,
        DateTime(
          _weeklyWeekStart!.year,
          _weeklyWeekStart!.month,
          _weeklyWeekStart!.day,
        ).toIso8601String(),
      );
    }
    await prefs.setStringList(
      _weeklyStreakKey,
      _weeklyStreak.map((v) => v ? '1' : '0').toList(growable: false),
    );
  }

  /// Debug-only helper to make it easy to verify the UI:
  /// seeds a login on this week's Monday with 1 coin / 1-day streak.
  /// Then, when [checkDailyReward] runs on Tuesday, it becomes 2 coins / 2-day streak,
  /// and Monday shows as active.
  Future<void> debugSeedMondayLoginForTesting() async {
    if (!kDebugMode) return;
    await _storageReady;

    final prefs = await SharedPreferences.getInstance();
    final alreadySeeded = prefs.getBool(_debugSeedMondayLoginKey) ?? false;
    if (alreadySeeded) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = _weekStartFor(today);

    _coins = 1;
    _streakCount = 1;
    _lastLoginDate = monday;
    _earnedDailyReward = false;

    _loginHistoryDays
      ..clear()
      ..add(monday);

    _pruneLoginHistory();
    _ensureWeeklyStreakFor(today);

    await _saveToStorage();
    await prefs.setBool(_debugSeedMondayLoginKey, true);
    notifyListeners();
  }

  DateTime _weekStartFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  void _ensureWeeklyStreakFor(DateTime day) {
    final start = _weekStartFor(day);
    // Always keep weekly cache in sync with login history.
    _weeklyWeekStart = start;
    for (var i = 0; i < 7; i++) {
      _weeklyStreak[i] = false;
    }

    final end = start.add(const Duration(days: 6));
    for (final d in _loginHistoryDays) {
      final normalized = DateTime(d.year, d.month, d.day);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
        final index = normalized.difference(start).inDays;
        if (index >= 0 && index < 7) {
          _weeklyStreak[index] = true;
        }
      }
    }

    // If we have a last login date in this week, ensure it's represented.
    if (_lastLoginDate != null) {
      final lastNorm = DateTime(
        _lastLoginDate!.year,
        _lastLoginDate!.month,
        _lastLoginDate!.day,
      );
      if (!lastNorm.isBefore(start) && !lastNorm.isAfter(end)) {
        final index = lastNorm.difference(start).inDays;
        if (index >= 0 && index < 7) {
          _weeklyStreak[index] = true;
        }
      }
    }

  }

  Future<void> checkDailyReward() async {
    await _storageReady;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final last = _lastLoginDate == null
        ? null
        : DateTime(
            _lastLoginDate!.year,
            _lastLoginDate!.month,
            _lastLoginDate!.day,
          );

    if (last != null && !last.isBefore(today)) {
      _earnedDailyReward = false;
      notifyListeners();
      return;
    }
    _ensureWeeklyStreakFor(today);

    // Prefer index relative to week start to avoid any weekday mapping drift.
    final int todayIndex = _weeklyWeekStart == null
        ? (now.weekday - 1)
        : today.difference(_weeklyWeekStart!).inDays;

    if (last == null) {
      _streakCount = 1;
    } else {
      final difference = today.difference(last).inDays;
      if (difference == 1) {
        _streakCount += 1;
      } else if (difference > 1) {
        _streakCount = 1;
        for (var i = 0; i < 7; i++) {
          _weeklyStreak[i] = false;
        }
      }
    }

    if (todayIndex >= 0 && todayIndex < 7) {
      _weeklyStreak[todayIndex] = true;
    }

    _lastLoginDate = today;
    _coins += 1;
    _earnedDailyReward = true;

    _addLoginDay(today);

    // Rebuild weekly cache from history (keeps UI correct even if the cache
    // was reset earlier in this session).
    _ensureWeeklyStreakFor(today);

    await _saveToStorage();

    if (kDebugMode) {
      print('Coins: $_coins');
      print('Streak: $_streakCount');
      print('Last login: ${_lastLoginDate?.toIso8601String()}');
      print('Weekly streak: $_weeklyStreak');
    }

    notifyListeners();
  }

  Future<void> updateStreak({DateTime? forDay}) async {
    await _storageReady;
    final day = forDay ?? DateTime.now();
    final normalized = DateTime(day.year, day.month, day.day);

    final last = _lastLoginDate == null
        ? null
        : DateTime(
            _lastLoginDate!.year,
            _lastLoginDate!.month,
            _lastLoginDate!.day,
          );

    if (last != null && !last.isBefore(normalized)) {
      return;
    }

    final yesterday = normalized.subtract(const Duration(days: 1));
    if (last != null && last.isAtSameMomentAs(yesterday)) {
      _streakCount += 1;
    } else {
      _streakCount = 1;
    }

    _ensureWeeklyStreakFor(normalized);
    if (_weeklyWeekStart != null) {
      final index = normalized.difference(_weeklyWeekStart!).inDays;
      if (index >= 0 && index < 7) {
        _weeklyStreak[index] = true;
      }
    }
    _lastLoginDate = normalized;
    _addLoginDay(normalized);
    await _saveToStorage();
    notifyListeners();
  }

  void _addLoginDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    _loginHistoryDays.removeWhere(
      (d) => d.year == normalized.year && d.month == normalized.month && d.day == normalized.day,
    );
    _loginHistoryDays.add(normalized);
    _loginHistoryDays.sort((a, b) => a.compareTo(b));
    _pruneLoginHistory();
  }

  void _pruneLoginHistory() {
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    _loginHistoryDays.removeWhere((d) => d.isBefore(cutoffDay));
  }

  void clearDailyRewardFlag() {
    if (_earnedDailyReward) {
      _earnedDailyReward = false;
      notifyListeners();
    }
  }

  Future<void> addCoins(int value) async {
    await _storageReady;
    _coins += value;
    await _saveToStorage();
    notifyListeners();
  }

  Future<bool> spendCoins(int value) async {
    await _storageReady;
    if (value <= 0) return true;
    if (_coins < value) return false;
    _coins -= value;
    await _saveToStorage();
    notifyListeners();
    return true;
  }

  Future<void> updateLoginDate(DateTime date) async {
    await _storageReady;
    _lastLoginDate = date;
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> setGender(String gender) async {
    await _storageReady;
    final normalized = gender.trim().toLowerCase();
    if (normalized != 'male' && normalized != 'female') return;
    if (_gender == normalized) return;
    _gender = normalized;
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> setProfileImageBytes(Uint8List? bytes) async {
    await _storageReady;
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

  Future<void> fetchProgress() async {
    // Placeholder: progress could be stored per-course in persistent storage.
    // Left as a stub to avoid duplicating backend logic.
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
