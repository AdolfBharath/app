import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/api_service.dart' as admin_api;
import '../services/token_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() : _api = ApiClient();

  final ApiClient _api;
  final List<AppUser> _users = [];
  AppUser? _currentUser;
  String? _lastLoginError;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get currentRole => _currentUser?.role;
  String? get lastLoginError => _lastLoginError;

  List<AppUser> get allUsers => List.unmodifiable(_users);
  List<AppUser> get students =>
      _users.where((user) => user.role == UserRole.student).toList();
  List<AppUser> get mentors =>
      _users.where((user) => user.role == UserRole.mentor).toList();
  List<AppUser> get admins =>
      _users.where((user) => user.role == UserRole.admin).toList();

  AppUser _userWithCourseIds(AppUser user, List<String> courseIds) {
    return AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      role: user.role,
      profilePic: user.profilePic,
      username: user.username,
      adminNo: user.adminNo,
      referralKey: user.referralKey,
      phone: user.phone,
      batchId: user.batchId,
      batchIds: user.batchIds,
      expertise: user.expertise,
      courseIds: courseIds,
      streakCount: user.streakCount,
      lastActiveDate: user.lastActiveDate,
      coins: user.coins,
      weeklyLogins: user.weeklyLogins,
    );
  }

  AppUser _userWithBatchIds(AppUser user, List<String> batchIds) {
    return AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      role: user.role,
      profilePic: user.profilePic,
      username: user.username,
      adminNo: user.adminNo,
      referralKey: user.referralKey,
      phone: user.phone,
      batchId: batchIds.isNotEmpty ? batchIds.first : user.batchId,
      batchIds: batchIds,
      expertise: user.expertise,
      courseIds: user.courseIds,
      streakCount: user.streakCount,
      lastActiveDate: user.lastActiveDate,
      coins: user.coins,
      weeklyLogins: user.weeklyLogins,
    );
  }

  AppUser _userWithReferralKey(AppUser user, String referralKey) {
    return AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      role: user.role,
      profilePic: user.profilePic,
      username: user.username,
      adminNo: user.adminNo,
      referralKey: referralKey,
      phone: user.phone,
      batchId: user.batchId,
      batchIds: user.batchIds,
      expertise: user.expertise,
      courseIds: user.courseIds,
      streakCount: user.streakCount,
      lastActiveDate: user.lastActiveDate,
      coins: user.coins,
      weeklyLogins: user.weeklyLogins,
    );
  }

  Future<String?> _fetchUserReferralKey(String userId) async {
    try {
      final rows = await _api.getJsonList(
        '/users?id=eq.$userId&select=referral_key',
        requiresAuth: false,
      );
      if (rows.isEmpty) return null;
      final key = rows.first['referral_key']?.toString().trim();
      return key == null || key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetchUserBatchIds(String userId) async {
    final ids = <String>{};

    Future<void> addFrom(String path) async {
      try {
        final rows = await _api.getJsonList(path, requiresAuth: false);
        for (final row in rows) {
          if (row is! Map) continue;
          final id = row['batch_id']?.toString().trim();
          if (id != null && id.isNotEmpty) ids.add(id);
        }
      } catch (_) {}
    }

    await addFrom('/student_batches?student_id=eq.$userId&select=batch_id');

    return ids.toList(growable: false);
  }

  void _syncCurrentUserIntoList() {
    if (_currentUser == null) return;
    final index = _users.indexWhere((u) => u.id == _currentUser!.id);
    if (index >= 0) {
      _users[index] = _currentUser!;
    }
  }

  AppUser _mapUserJson(Map<dynamic, dynamic> map, {AppUser? fallback}) {
    return AppUser(
      id: map['id'].toString(),
      name: (map['name'] ?? fallback?.name ?? '') as String,
      email: (map['email'] ?? fallback?.email ?? '') as String,
      password: '',
      profilePic:
          (map['avatar_url'] ?? map['profile_pic'] ?? fallback?.profilePic)
              as String?,
      role: _roleFromString(
        (map['role'] ??
                (fallback != null ? _roleToString(fallback.role) : 'student'))
            as String,
      ),
      username: (map['username'] ?? fallback?.username) as String?,
      adminNo: (map['admin_no'] ?? fallback?.adminNo) as String?,
      referralKey:
          (map['referral_key'] ?? map['reference_key'] ?? fallback?.referralKey)
              as String?,
      phone: (map['phone'] ?? fallback?.phone) as String?,
      batchId: map['batch_id']?.toString() ?? fallback?.batchId,
      batchIds: _parseBatchIds(map, fallback: fallback?.batchIds ?? const []),
      expertise: _parseExpertise(map['expertise'] ?? fallback?.expertise),
      courseIds: _parseCourseIds(
        map,
        fallback: fallback?.courseIds ?? const [],
      ),
      streakCount:
          (map['streak_count'] as num?)?.toInt() ?? fallback?.streakCount ?? 0,
      lastActiveDate: map['last_active_date'] != null
          ? DateTime.tryParse(map['last_active_date'].toString())
          : fallback?.lastActiveDate,
      coins: (map['coins'] as num?)?.toInt() ?? fallback?.coins ?? 0,
      weeklyLogins: _parseWeeklyLogins(
        map['weekly_logins'],
        fallback: fallback?.weeklyLogins,
      ),
    );
  }

  List<bool> _parseWeeklyLogins(dynamic raw, {List<bool>? fallback}) {
    if (raw is List) {
      return raw.map((e) => e == true).toList().cast<bool>();
    }
    return List<bool>.from(
      fallback ?? const [false, false, false, false, false, false, false],
    );
  }

  Future<bool> login(String email, String password) async {
    try {
      _lastLoginError = null;
      // Use the server-side RPC `lms_password_login` which safely checks
      // the password on the server and avoids exposing the password column
      // to the anon role in RLS-enabled environments.
      final json = await _api.postJson('/rpc/lms_password_login', {
        'login_email': email.trim(),
        'login_password': password,
      }, requiresAuth: false);

      if (json.isEmpty) {
        _lastLoginError = 'Invalid email or password';
        return false;
      }

      var updatedUser = await _processUserGamification(json);
      final referralKey = await _fetchUserReferralKey(updatedUser.id);
      if (referralKey != null) {
        updatedUser = _userWithReferralKey(updatedUser, referralKey);
      }
      try {
        final ids = await admin_api.ApiService.instance.getUserCourseIds(
          updatedUser.id,
        );
        if (ids.isNotEmpty) {
          updatedUser = _userWithCourseIds(updatedUser, ids);
        }
      } catch (_) {
        // Keep the logged-in user from the RPC if assignment lookup fails.
      }
      final batchIds = await _fetchUserBatchIds(updatedUser.id);
      if (batchIds.isNotEmpty) {
        updatedUser = _userWithBatchIds(updatedUser, batchIds);
      }

      _currentUser = updatedUser;
      await TokenService.saveToken(updatedUser.id);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('Login failed: ${e.body}');
      }

      // Try to extract a friendly message from a JSON error body.
      try {
        final decoded = jsonDecode(e.body);
        if (decoded is Map && decoded['message'] is String) {
          _lastLoginError = decoded['message'] as String;
        }
      } catch (_) {
        // ignore parse errors
      }

      _lastLoginError ??=
          'Login failed (HTTP ${e.statusCode}). Please check your credentials.';
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }

      final msg = e.toString();
      if (msg.contains('Request timeout')) {
        _lastLoginError =
            'Request timed out. Is the backend running and reachable?';
      } else if (msg.contains('SocketException') ||
          msg.contains('Connection refused')) {
        _lastLoginError =
            'Cannot reach backend. Check Wi‑Fi, IP address, and firewall.';
      } else if (msg.contains('CLEARTEXT') || msg.contains('Cleartext')) {
        _lastLoginError =
            'HTTP blocked by Android (cleartext). Enable cleartext traffic or use HTTPS.';
      } else {
        _lastLoginError = 'Login failed: $msg';
      }
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    // Clear any stored token on logout.
    TokenService.removeToken();
    notifyListeners();
  }

  void updateCurrentUserCoins(int coins) {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      role: user.role,
      username: user.username,
      adminNo: user.adminNo,
      referralKey: user.referralKey,
      phone: user.phone,
      batchId: user.batchId,
      batchIds: user.batchIds,
      expertise: user.expertise,
      courseIds: user.courseIds,
      profilePic: user.profilePic,
      streakCount: user.streakCount,
      lastActiveDate: user.lastActiveDate,
      coins: coins < 0 ? 0 : coins,
      weeklyLogins: user.weeklyLogins,
    );
    _syncCurrentUserIntoList();
    notifyListeners();
  }

  /// Sends a password-reset email. Always returns `true` to avoid
  /// leaking whether an account exists for the given email address.
  Future<bool> forgotPassword(String email) async {
    try {
      final emailLower = email.trim().toLowerCase();
      final users = await _api.getJsonList(
        '/users?email=eq.$emailLower',
        requiresAuth: false,
      );
      if (users.isNotEmpty) {
        final userId = users.first['id'];
        await _api.postJson('/password_reset_tokens', {
          'user_id': userId,
          'token': DateTime.now().millisecondsSinceEpoch
              .toString(), // Mock token generator for now
          'expires_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }, requiresAuth: false);
      }
    } catch (_) {
      // Silently ignore — we never reveal whether the email exists.
    }
    return true;
  }

  Future<bool> addUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    try {
      await admin_api.ApiService.instance.createUser(
        name: name,
        email: email,
        password: password,
        role: _roleToString(role),
        phone: phone,
      );

      // Refresh the list from backend so provider state matches DB
      await loadUsers();
      return true;
    } on admin_api.DuplicateEmailException catch (e) {
      if (kDebugMode) {
        print('Add user failed (duplicate email): ${e.message}');
      }
      return false;
    } on admin_api.ApiException catch (e) {
      if (kDebugMode) {
        print('Add user failed: ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Add user error: $e');
      }
      return false;
    }
  }

  Future<bool> updateCurrentAdminProfile({
    String? name,
    String? email,
    String? password,
  }) async {
    if (_currentUser == null) return false;

    try {
      final body = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) {
        body['name'] = name.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      if (password != null && password.trim().isNotEmpty) {
        body['password'] = password.trim();
      }

      if (body.isEmpty) return false;

      final json = await _api.patchJson(
        '/users?id=eq.${_currentUser!.id}',
        body,
      );

      _currentUser = AppUser(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String,
        password: '',
        profilePic: (json['avatar_url'] ?? json['profile_pic']) as String?,
        role: _roleFromString(json['role'] as String),
        username: json['username'] as String?,
        adminNo: json['admin_no'] as String?,
        referralKey: json['referral_key'] as String?,
        phone: json['phone'] as String?,
        batchId: json['batch_id']?.toString(),
        batchIds: _parseBatchIds(
          json,
          fallback: _currentUser?.batchIds ?? const [],
        ),
        expertise: _parseExpertise(json['expertise']),
        courseIds: _parseCourseIds(json),
      );
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('Update profile failed: ${e.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Update profile error: $e');
      }
      return false;
    }
  }

  Future<bool> updateCurrentUserProfile({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? currentPassword,
    String? newPassword,
  }) async {
    if (_currentUser == null) return false;

    try {
      final body = <String, dynamic>{};

      if (name != null) body['name'] = name;
      if (username != null) body['username'] = username;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;

      if (currentPassword != null && currentPassword.trim().isNotEmpty) {
        // Keep for client-side validation only; backend expects `password`.
      }
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        body['password'] = newPassword.trim();
      }

      final json = await _api.patchJson(
        '/users?id=eq.${_currentUser!.id}',
        body,
      );

      _currentUser = AppUser(
        id: json['id'].toString(),
        name: (json['name'] ?? _currentUser!.name) as String,
        email: (json['email'] ?? _currentUser!.email) as String,
        password: '',
        profilePic:
            (json['avatar_url'] ??
                    json['profile_pic'] ??
                    _currentUser!.profilePic)
                as String?,
        role: _roleFromString(
          (json['role'] ?? _roleToString(_currentUser!.role)) as String,
        ),
        username: (json['username'] ?? _currentUser!.username) as String?,
        adminNo: (json['admin_no'] ?? _currentUser!.adminNo) as String?,
        referralKey:
            (json['referral_key'] ?? _currentUser!.referralKey) as String?,
        phone: (json['phone'] ?? _currentUser!.phone) as String?,
        batchId: json['batch_id']?.toString() ?? _currentUser!.batchId,
        batchIds: _parseBatchIds(json, fallback: _currentUser!.batchIds),
        expertise: _currentUser!.expertise,
        courseIds: _parseCourseIds(json, fallback: _currentUser!.courseIds),
      );
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('Update current user profile failed: ${e.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Update current user profile error: $e');
      }
      return false;
    }
  }

  Future<bool> updateUserProfile({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? password,
    String? currentPassword,
  }) {
    return updateCurrentUserProfile(
      name: name,
      username: username,
      email: email,
      phone: phone,
      currentPassword: currentPassword,
      newPassword: password,
    );
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    try {
      // First verify current password (since we store it in plain text for this demo)
      // Verify current password via the RPC (server-side) rather than
      // selecting the password column directly (which is hidden by RLS).
      final verify = await _api.postJson('/rpc/lms_password_login', {
        'login_email': _currentUser!.email,
        'login_password': currentPassword,
      }, requiresAuth: false);

      if (verify.isEmpty) {
        if (kDebugMode) {
          print('Change password failed: Incorrect current password');
        }
        return false;
      }

      // Then update to new password (this endpoint requires write access)
      await _api.patchJson('/users?id=eq.${_currentUser!.id}', {
        'password': newPassword.trim(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Change password error: $e');
      }
      return false;
    }
  }

  Future<void> loadUsers() async {
    try {
      List<dynamic> list;
      try {
        list = await admin_api.ApiService.instance.getUsers();
      } on admin_api.UnauthorizedApiException catch (_) {
        // Fallback to an unauthenticated fetch if the admin endpoint requires
        // a token the client doesn't have. This keeps the UI usable for
        // environments where the publishable key grants read access.
        list = await _api.getJsonList(
          '/users?select=id,name,email,role,created_at',
          requiresAuth: false,
        );
      }
      _users
        ..clear()
        ..addAll(
          list.map((item) {
            final map = item as Map<String, dynamic>;
            final fallback =
                _currentUser?.id == map['id']?.toString() ? _currentUser : null;
            return _mapUserJson(map, fallback: fallback);
          }),
        );

      if (_currentUser != null) {
        final current = _users
            .where((u) => u.id == _currentUser!.id)
            .cast<AppUser?>()
            .firstWhere((u) => u != null, orElse: () => null);
        if (current != null) {
          _currentUser = current;
        }
      }

      notifyListeners();
    } on admin_api.ApiException catch (e) {
      if (kDebugMode) {
        print('Load users failed: ${e.message}');
      }
    }
  }

  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      final list = await _api.getJsonList('/users?id=eq.${_currentUser!.id}');
      if (list.isEmpty) throw Exception('User not found');
      final map = list.first as Map<String, dynamic>;
      var refreshed = await _processUserGamification(
        map,
        fallback: _currentUser,
      );

      try {
        final ids = await admin_api.ApiService.instance.getUserCourseIds(
          refreshed.id,
        );
        if (ids.isNotEmpty) {
          refreshed = _userWithCourseIds(refreshed, ids);
        }
      } catch (_) {
        // Keep existing courseIds if user_courses lookup fails.
      }

      final batchIds = await _fetchUserBatchIds(refreshed.id);
      if (batchIds.isNotEmpty) {
        refreshed = _userWithBatchIds(refreshed, batchIds);
      }

      // Some backends omit course_ids in /users/me. Derive assignments from
      // role-specific course feeds to keep provider/UI in sync.
      if (refreshed.courseIds.isEmpty) {
        try {
          if (refreshed.role == UserRole.mentor) {
            final mentorCourses = await admin_api.ApiService.instance
                .getMentorCourses();
            refreshed = _userWithCourseIds(
              refreshed,
              mentorCourses
                  .map((c) => c.id)
                  .where((id) => id.isNotEmpty)
                  .toList(growable: false),
            );
          } else if (refreshed.role == UserRole.student) {
            final allCourses = await admin_api.ApiService.instance.getCourses();
            refreshed = _userWithCourseIds(
              refreshed,
              allCourses
                  .where((c) => c.isMyCourse)
                  .map((c) => c.id)
                  .where((id) => id.isNotEmpty)
                  .toList(growable: false),
            );
          }
        } catch (_) {
          // Keep refreshed user from /users/me even if course fallback fails.
        }
      }

      _currentUser = refreshed;
      _syncCurrentUserIntoList();

      if (kDebugMode) {
        print(
          'Refreshed user ${_currentUser!.id} courses: ${_currentUser!.courseIds}',
        );
      }

      notifyListeners();
      return;
    } catch (_) {
      // Fallback below keeps session in sync even if /users/me is unavailable.
    }

    await loadUsers();
  }

  /// Consolidates streak and coin logic. Checks if the user's gamification
  /// data needs updating (e.g. first login of the day) and syncs with Supabase.
  Future<AppUser> _processUserGamification(
    Map<String, dynamic> json, {
    AppUser? fallback,
  }) async {
    int streak =
        (json['streak_count'] as num?)?.toInt() ?? fallback?.streakCount ?? 0;
    DateTime? lastActive = json['last_active_date'] != null
        ? DateTime.tryParse(json['last_active_date'].toString())
        : fallback?.lastActiveDate;
    int coins = (json['coins'] as num?)?.toInt() ?? fallback?.coins ?? 0;
    List<bool> weeklyLogins = _parseWeeklyLogins(
      json['weekly_logins'],
      fallback: fallback?.weeklyLogins,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool needsUpdate = false;

    if (lastActive == null || lastActive.isBefore(today)) {
      needsUpdate = true;
      final yesterday = today.subtract(const Duration(days: 1));

      // Streak logic: check if they were active yesterday
      if (lastActive != null &&
          (lastActive.isAtSameMomentAs(yesterday) ||
              lastActive.isAfter(yesterday))) {
        if (!lastActive.isAtSameMomentAs(today)) {
          streak += 1;
        }
      } else {
        streak = 1; // Reset to 1 on first day or if a day was missed
      }

      // Reset weekly array if we are in a new week
      bool isSameWeek(DateTime a, DateTime b) {
        final aMonday = a.subtract(Duration(days: a.weekday - 1));
        final bMonday = b.subtract(Duration(days: b.weekday - 1));
        return aMonday.year == bMonday.year &&
            aMonday.month == bMonday.month &&
            aMonday.day == bMonday.day;
      }

      if (lastActive == null || !isSameWeek(today, lastActive)) {
        weeklyLogins = List.generate(7, (_) => false);
      }

      // Award daily login reward
      if (now.weekday >= 1 && now.weekday <= 7) {
        if (!weeklyLogins[now.weekday - 1]) {
          coins += 10;
          weeklyLogins[now.weekday - 1] = true;
        }
      }

      lastActive = today;
    }

    final earnedLoginCoins = streak * 10;
    if (streak > 0 && coins < earnedLoginCoins) {
      coins = earnedLoginCoins;
      needsUpdate = true;
    }

    final user = _mapUserJson(json, fallback: fallback);
    // Create a version of the user with the updated streak/coins
    final updatedUser = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      role: user.role,
      profilePic: user.profilePic,
      username: user.username,
      adminNo: user.adminNo,
      referralKey: user.referralKey,
      phone: user.phone,
      batchId: user.batchId,
      batchIds: user.batchIds,
      expertise: user.expertise,
      courseIds: user.courseIds,
      streakCount: streak,
      lastActiveDate: lastActive,
      coins: coins,
      weeklyLogins: weeklyLogins,
    );

    if (needsUpdate) {
      try {
        await _api.patchJson('/users?id=eq.${updatedUser.id}', {
          'streak_count': streak,
          'last_active_date': (lastActive ?? today).toIso8601String(),
          'coins': coins,
          'weekly_logins': weeklyLogins,
        });
      } catch (e) {
        if (kDebugMode) print('Failed to update gamification data: $e');
      }
    }

    return updatedUser;
  }

  List<String> _parseExpertise(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> _parseCourseIds(
    Map<dynamic, dynamic> raw, {
    List<String> fallback = const [],
  }) {
    final ids = <String>{};

    void add(dynamic v) {
      if (v == null) return;
      final id = v.toString().trim();
      if (id.isNotEmpty) ids.add(id);
    }

    add(raw['course_id']);
    add(raw['courseId']);
    add(raw['enrolled_course_id']);

    final courseIds = raw['course_ids'];
    if (courseIds is List) {
      for (final c in courseIds) {
        add(c);
      }
    }

    final courses = raw['courses'];
    if (courses is List) {
      for (final c in courses) {
        if (c is Map) {
          add(c['id']);
          add(c['course_id']);
        } else {
          add(c);
        }
      }
    }

    final userCourses = raw['user_courses'];
    if (userCourses is List) {
      for (final c in userCourses) {
        if (c is Map) {
          add(c['course_id']);
          add(c['courses'] is Map ? (c['courses'] as Map)['id'] : null);
        } else {
          add(c);
        }
      }
    }

    if (ids.isNotEmpty) {
      return ids.toList(growable: false);
    }
    return fallback;
  }

  List<String> _parseBatchIds(
    Map<dynamic, dynamic> raw, {
    List<String> fallback = const [],
  }) {
    final ids = <String>{};

    void add(dynamic v) {
      if (v == null) return;
      final id = v.toString().trim();
      if (id.isNotEmpty) ids.add(id);
    }

    add(raw['batch_id']);
    add(raw['batchId']);

    final batchIds = raw['batch_ids'];
    if (batchIds is List) {
      for (final b in batchIds) {
        add(b);
      }
    }

    final batches = raw['batches'];
    if (batches is List) {
      for (final b in batches) {
        if (b is Map) {
          add(b['id']);
          add(b['batch_id']);
        } else {
          add(b);
        }
      }
    }

    for (final userBatches in [
      raw['student_batches'],
    ]) {
      if (userBatches is! List) continue;
      for (final b in userBatches) {
        if (b is Map) {
          add(b['batch_id']);
          add(b['batches'] is Map ? (b['batches'] as Map)['id'] : null);
        } else {
          add(b);
        }
      }
    }

    if (ids.isNotEmpty) return ids.toList(growable: false);
    return fallback;
  }

  UserRole _roleFromString(String role) {
    final normalized = role.toLowerCase();
    switch (normalized) {
      case 'admin':
        return UserRole.admin;
      case 'mentor':
        return UserRole.mentor;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.mentor:
        return 'mentor';
      case UserRole.student:
        return 'student';
    }
  }
}
