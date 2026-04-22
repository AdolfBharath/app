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
      username: user.username,
      adminNo: user.adminNo,
      phone: user.phone,
      batchId: user.batchId,
      expertise: user.expertise,
      courseIds: courseIds,
    );
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
      role: _roleFromString(
        (map['role'] ?? (fallback != null ? _roleToString(fallback.role) : 'student')) as String,
      ),
      username: (map['username'] ?? fallback?.username) as String?,
      adminNo: (map['admin_no'] ?? fallback?.adminNo) as String?,
      phone: (map['phone'] ?? fallback?.phone) as String?,
      batchId: map['batch_id']?.toString() ?? fallback?.batchId,
      expertise: _parseExpertise(map['expertise'] ?? fallback?.expertise),
      courseIds: _parseCourseIds(map, fallback: fallback?.courseIds ?? const []),
    );
  }

  Future<bool> login(String email, String password) async {
    try {
      _lastLoginError = null;
      final json = await _api.postJson(
        '/auth/login',
        {
          'email': email,
          'password': password,
        },
        requiresAuth: false,
      );

      final user = AppUser(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String,
        password: '',
        role: _roleFromString(json['role'] as String),
        username: json['username'] as String?,
        adminNo: json['admin_no'] as String?,
        phone: json['phone'] as String?,
        batchId: json['batch_id']?.toString(),
        expertise: _parseExpertise(json['expertise']),
        courseIds: _parseCourseIds(json),
      );

      // Persist JWT token for authenticated admin endpoints if provided.
      final token = json['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await TokenService.saveToken(token);
      }

      _currentUser = user;
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

      _lastLoginError ??= 'Login failed (HTTP ${e.statusCode}). Please check your credentials.';
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }

      final msg = e.toString();
      if (msg.contains('Request timeout')) {
        _lastLoginError = 'Request timed out. Is the backend running and reachable?';
      } else if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        _lastLoginError = 'Cannot reach backend. Check Wi‑Fi, IP address, and firewall.';
      } else if (msg.contains('CLEARTEXT') || msg.contains('Cleartext')) {
        _lastLoginError = 'HTTP blocked by Android (cleartext). Enable cleartext traffic or use HTTPS.';
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

      final json = await _api.putJson('/users/${_currentUser!.id}', body);

      _currentUser = AppUser(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String,
        password: '',
        role: _roleFromString(json['role'] as String),
        username: json['username'] as String?,
        adminNo: json['admin_no'] as String?,
        phone: json['phone'] as String?,
        batchId: json['batch_id']?.toString(),
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
        body['currentPassword'] = currentPassword;
      }
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        body['newPassword'] = newPassword;
      }

      final json = await _api.putJson('/users/me', body);

      _currentUser = AppUser(
        id: json['id'].toString(),
        name: (json['name'] ?? _currentUser!.name) as String,
        email: (json['email'] ?? _currentUser!.email) as String,
        password: '',
        role: _roleFromString((json['role'] ?? _roleToString(_currentUser!.role)) as String),
        username: (json['username'] ?? _currentUser!.username) as String?,
        adminNo: (json['admin_no'] ?? _currentUser!.adminNo) as String?,
        phone: (json['phone'] ?? _currentUser!.phone) as String?,
        batchId: json['batch_id']?.toString() ?? _currentUser!.batchId,
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
      final ok = await admin_api.ApiService.instance.changeAdminPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return ok;
    } on admin_api.ApiException catch (e) {
      if (kDebugMode) {
        print('Change password failed: ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Change password error: $e');
      }
      return false;
    }
  }

  Future<void> loadUsers() async {
    try {
      final list = await _api.getJsonList('/users');
      _users
        ..clear()
        ..addAll(
          list.map((item) {
            final map = item as Map<String, dynamic>;
            return _mapUserJson(map);
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
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('Load users failed: ${e.body}');
      }
    }
  }

  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      final map = await _api.getJsonObject('/users/me');
      var refreshed = _mapUserJson(map, fallback: _currentUser);

      // Some backends omit course_ids in /users/me. Derive assignments from
      // role-specific course feeds to keep provider/UI in sync.
      if (refreshed.courseIds.isEmpty) {
        try {
          if (refreshed.role == UserRole.mentor) {
            final mentorCourses = await admin_api.ApiService.instance.getMentorCourses();
            refreshed = _userWithCourseIds(
              refreshed,
              mentorCourses.map((c) => c.id).where((id) => id.isNotEmpty).toList(growable: false),
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
        print('Refreshed user ${_currentUser!.id} courses: ${_currentUser!.courseIds}');
      }

      notifyListeners();
      return;
    } catch (_) {
      // Fallback below keeps session in sync even if /users/me is unavailable.
    }

    await loadUsers();
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

    if (ids.isNotEmpty) {
      return ids.toList(growable: false);
    }
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
