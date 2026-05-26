import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_service.dart';
import '../utils/supabase_config.dart';

class BatchChatAuthor {
  const BatchChatAuthor({
    required this.id,
    required this.name,
    required this.role,
    required this.username,
  });

  final String id;
  final String name;
  final String role;
  final String? username;
}

class BatchChatReply {
  const BatchChatReply({
    required this.id,
    required this.postId,
    required this.parentReplyId,
    required this.content,
    required this.createdAt,
    required this.deletedAt,
    required this.author,
  });

  final String id;
  final String postId;
  final String? parentReplyId;
  final String content;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final BatchChatAuthor author;

  bool get isDeleted => deletedAt != null;
}

class BatchChatPost {
  BatchChatPost({
    required this.id,
    required this.batchId,
    required this.content,
    required this.createdAt,
    required this.deletedAt,
    required this.author,
    required this.upvotes,
    required this.didUpvote,
    List<BatchChatReply>? replies,
  }) : replies = replies ?? <BatchChatReply>[];

  final String id;
  final String batchId;
  final String content;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final BatchChatAuthor author;
  int upvotes;
  bool didUpvote;
  final List<BatchChatReply> replies;

  bool get isDeleted => deletedAt != null;
}

class ChatProvider extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  bool _isBanned = false;
  bool _isRestricted = false;
  String? _batchName;
  final List<BatchChatPost> _posts = [];
  String? _activeBatchId;
  bool _hasOlderMessages = true;
  DateTime? _lastLoadStartedAt;

  /// Chat messages that have been *seen* for more than this duration are
  /// automatically deleted from the backend and hidden from the UI.
  static const Duration _messageTtl = Duration(days: 7);

  bool get loading => _loading;
  String? get error => _error;
  bool get isBanned => _isBanned;
  bool get isRestricted => _isRestricted;
  String? get batchName => _batchName;
  UnmodifiableListView<BatchChatPost> get posts => UnmodifiableListView(_posts);
  bool get hasOlderMessages => _hasOlderMessages;

  Future<String?> _getUserId() async {
    try {
      return await TokenService.getToken();
    } catch (_) {
      return null;
    }
  }

  void clearState() {
    _loading = false;
    _error = null;
    _isBanned = false;
    _isRestricted = false;
    _batchName = null;
    _activeBatchId = null;
    _hasOlderMessages = true;
    _posts.clear();
    notifyListeners();
  }

  Future<Map<String, BatchChatAuthor>> _loadAuthors(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final joined = ids.map((id) => '"$id"').join(',');
    final url = ApiConfig.uri('/users', {
      'id': 'in.($joined)',
      'select': 'id,name,role,username',
    });

    final response = await http.get(
      url,
      headers: {
        'apikey': SupabaseConfig.apiKey,
        'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {};
    }

    final raw = jsonDecode(response.body) as List<dynamic>;
    final map = <String, BatchChatAuthor>{};
    for (final item in raw) {
      final data = item as Map<String, dynamic>;
      final id = (data['id'] ?? '').toString();
      if (id.isEmpty) continue;
      map[id] = BatchChatAuthor(
        id: id,
        name: (data['name'] ?? 'User').toString(),
        role: (data['role'] ?? 'student').toString(),
        username: data['username']?.toString(),
      );
    }
    return map;
  }

  Future<void> _loadBanState(String batchId) async {
    final userId = await _getUserId();
    if (userId == null) return;
    final url = ApiConfig.uri('/batch_chat_bans', {
      'batch_id': 'eq.$batchId',
      'user_id': 'eq.$userId',
      'select': 'is_banned,is_restricted',
    });

    final response = await http.get(
      url,
      headers: {
        'apikey': SupabaseConfig.apiKey,
        'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) return;
    final raw = jsonDecode(response.body) as List<dynamic>;
    if (raw.isEmpty) {
      _isBanned = false;
      _isRestricted = false;
      return;
    }

    final row = raw.first as Map<String, dynamic>;
    _isBanned = row['is_banned'] == true;
    _isRestricted = row['is_restricted'] == true;
  }

  Future<void> loadBatchChat(String batchId) async {
    final now = DateTime.now();
    if (_loading &&
        _activeBatchId == batchId &&
        _lastLoadStartedAt != null &&
        now.difference(_lastLoadStartedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _activeBatchId = batchId;
    _lastLoadStartedAt = now;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final url = ApiConfig.uri(
        '/batch_chats',
        {
          'batch_id': 'eq.$batchId',
          'select': 'id,batch_id,user_id,message,parent_id,created_at,deleted_at',
          'order': 'created_at.desc',
          'limit': '30',
        },
      );

      var response = await http.get(
        url,
        headers: {
          'apikey': SupabaseConfig.apiKey,
          'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
          'Content-Type': 'application/json',
        },
      );

      var chatTable = '/batch_chats';
      var usesContentColumn = false;
      if (response.statusCode == 400) {
        response = await http.get(
          ApiConfig.uri('/batch_chats', {
            'batch_id': 'eq.$batchId',
            'select': 'id,batch_id,user_id,message,created_at',
            'order': 'created_at.desc',
            'limit': '30',
          }),
          headers: {
            'apikey': SupabaseConfig.apiKey,
            'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
            'Content-Type': 'application/json',
          },
        );
      }
      if (response.statusCode == 400 || response.statusCode == 404) {
        chatTable = '/batch_chat_posts';
        usesContentColumn = true;
        response = await http.get(
          ApiConfig.uri(chatTable, {
            'batch_id': 'eq.$batchId',
            'select': 'id,batch_id,user_id,content,created_at',
            'order': 'created_at.desc',
            'limit': '30',
          }),
          headers: {
            'apikey': SupabaseConfig.apiKey,
            'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
            'Content-Type': 'application/json',
          },
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> rawChats = (jsonDecode(response.body) as List)
            .map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              if (usesContentColumn) {
                map['message'] = map['content'];
              }
              return map;
            })
            .toList(growable: false);
        _hasOlderMessages = rawChats.length == 30;
        final authorIds = rawChats
            .map((p) => (p as Map<String, dynamic>)['user_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        final authors = await _loadAuthors(authorIds);
        await _loadBanState(batchId);

        final allChats = rawChats
            .map((p) => p as Map<String, dynamic>)
            .toList()
            .reversed
            .toList(growable: false);
        final posts = allChats.where((p) => p['parent_id'] == null).toList();
        final replies = allChats.where((p) => p['parent_id'] != null).toList();

        final postsList = posts.map((p) {
          final userId = p['user_id']?.toString() ?? '';
          final author = authors[userId] ??
              BatchChatAuthor(
                id: userId,
                name: 'Student',
                role: 'student',
                username: null,
              );

          final postId = p['id']?.toString() ?? '';
          final postReplies = replies.where((r) => r['parent_id'].toString() == postId).map((r) {
             final replyUserId = r['user_id']?.toString() ?? '';
             final replyAuthor = authors[replyUserId] ?? BatchChatAuthor(id: replyUserId, name: 'Student', role: 'student', username: null);
             return BatchChatReply(
               id: r['id']?.toString() ?? '',
               postId: postId,
               parentReplyId: null,
               content: r['message']?.toString() ?? '',
               createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
               deletedAt: null,
               author: replyAuthor,
             );
          }).toList();

          return BatchChatPost(
            id: postId,
            batchId: p['batch_id']?.toString() ?? '',
            content: p['message']?.toString() ?? '',
            createdAt: DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
            deletedAt: null,
            author: author,
            upvotes: 0,
            didUpvote: false,
            replies: postReplies,
          );
        }).toList();

        // ── 7-day auto-expiry ───────────────────────────────────────────────
        final now = DateTime.now();
        final freshPosts = <BatchChatPost>[];
        final expiredPosts = <BatchChatPost>[];
        for (final post in postsList) {
          if (now.difference(post.createdAt) > _messageTtl) {
            expiredPosts.add(post);
          } else {
            freshPosts.add(post);
          }
        }
        // Delete expired posts from the backend (fire-and-forget).
        for (final post in expiredPosts) {
          _deletePostFromBackend(
            batchId: batchId,
            postId: post.id,
            table: chatTable,
          );
          // Also delete their replies.
          for (final reply in post.replies) {
            _deletePostFromBackend(
              batchId: batchId,
              postId: reply.id,
              table: chatTable,
            );
          }
        }
        // ───────────────────────────────────────────────────────────────────

        _posts
          ..clear()
          ..addAll(freshPosts);
      } else {
        _error = 'Failed to load chat. Code: ${response.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadOlderMessages(String batchId) async {
    if (_loading || !_hasOlderMessages || _posts.isEmpty) return;
    final before = _posts.first.createdAt.toUtc().toIso8601String();
    _loading = true;
    notifyListeners();
    try {
      final url = ApiConfig.uri('/batch_chats', {
        'batch_id': 'eq.$batchId',
        'created_at': 'lt.$before',
        'select': 'id,batch_id,user_id,message,parent_id,created_at,deleted_at',
        'order': 'created_at.desc',
        'limit': '30',
      });
      final response = await http.get(
        url,
        headers: {
          'apikey': SupabaseConfig.apiKey,
          'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final rawChats = jsonDecode(response.body) as List<dynamic>;
      _hasOlderMessages = rawChats.length == 30;
      final authorIds = rawChats
          .map((p) => (p as Map<String, dynamic>)['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final authors = await _loadAuthors(authorIds);
      final allChats = rawChats
          .map((p) => p as Map<String, dynamic>)
          .toList()
          .reversed
          .toList(growable: false);
      final posts = allChats.where((p) => p['parent_id'] == null).map((p) {
        final userId = p['user_id']?.toString() ?? '';
        return BatchChatPost(
          id: p['id']?.toString() ?? '',
          batchId: p['batch_id']?.toString() ?? '',
          content: p['message']?.toString() ?? '',
          createdAt:
              DateTime.tryParse(p['created_at']?.toString() ?? '') ??
              DateTime.now(),
          deletedAt: DateTime.tryParse(p['deleted_at']?.toString() ?? ''),
          author:
              authors[userId] ??
              BatchChatAuthor(
                id: userId,
                name: 'Student',
                role: 'student',
                username: null,
              ),
          upvotes: 0,
          didUpvote: false,
        );
      }).toList(growable: false);
      _posts.insertAll(0, posts.where((p) => !_posts.any((e) => e.id == p.id)));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> createPost(String batchId, String content) async {
    final text = content.trim();
    if (text.isEmpty) return 'Message is empty';

    try {
      final userId = await _getUserId();
      if (userId == null) return 'Not authenticated';
      if (_isBanned) return 'You are banned from this chat';
      if (_isRestricted) return 'You are restricted from posting';

      final url = ApiConfig.uri('/batch_chats');

      var response = await http.post(
        url,
        headers: {
          'apikey': SupabaseConfig.apiKey,
          'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: jsonEncode({
          'batch_id': batchId,
          'user_id': userId,
          'message': text,
        }),
      );

      if (response.statusCode == 400 || response.statusCode == 404) {
        response = await http.post(
          ApiConfig.uri('/batch_chat_posts'),
          headers: {
            'apikey': SupabaseConfig.apiKey,
            'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation'
          },
          body: jsonEncode({
            'batch_id': batchId,
            'user_id': userId,
            'content': text,
          }),
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await loadBatchChat(batchId);
        return null;
      }
      return 'Failed to send message: ${response.body}';
    } catch (e) {
      return e.toString();
    }
  }

  // --- Stubs to prevent UI from breaking ---
  Future<String?> createReply({required String batchId, required String postId, required String content, String? parentReplyId}) async {
    final text = content.trim();
    if (text.isEmpty) return 'Message is empty';

    try {
      final userId = await _getUserId();
      if (userId == null) return 'Not authenticated';
      if (_isBanned) return 'You are banned from this chat';
      if (_isRestricted) return 'You are restricted from posting';

      final url = ApiConfig.uri('/batch_chats');

      var response = await http.post(
        url,
        headers: {
          'apikey': SupabaseConfig.apiKey,
          'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: jsonEncode({
          'batch_id': batchId,
          'user_id': userId,
          'message': text,
          'parent_id': postId,
        }),
      );

      if (response.statusCode == 400 || response.statusCode == 404) {
        response = await http.post(
          ApiConfig.uri('/batch_chat_posts'),
          headers: {
            'apikey': SupabaseConfig.apiKey,
            'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation'
          },
          body: jsonEncode({
            'batch_id': batchId,
            'user_id': userId,
            'content': text,
            'parent_id': postId,
          }),
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await loadBatchChat(batchId);
        return null;
      }
      return 'Failed to send reply: ${response.body}';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleUpvote({required String batchId, required String postId}) async {
    return null;
  }

  Future<String?> deletePost({required String batchId, required String postId}) async {
    try {
      _deletePostFromBackend(batchId: batchId, postId: postId);
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteReply({required String batchId, required String replyId}) async {
    try {
      _deletePostFromBackend(batchId: batchId, postId: replyId);
      for (final post in _posts) {
        post.replies.removeWhere((r) => r.id == replyId);
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sends a hard DELETE to the batch_chats table for the given row id.
  /// Fire-and-forget: errors are swallowed so callers are never blocked.
  void _deletePostFromBackend({
    required String batchId,
    required String postId,
    String table = '/batch_chats',
  }) {
    final url = ApiConfig.uri(table, {'id': 'eq.$postId'});
    http.delete(
      url,
      headers: {
        'apikey': SupabaseConfig.apiKey,
        'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
        'Content-Type': 'application/json',
      },
    ).then((response) {
      if (response.statusCode == 404 && table != '/batch_chat_posts') {
        _deletePostFromBackend(
          batchId: batchId,
          postId: postId,
          table: '/batch_chat_posts',
        );
      }
    }).catchError((dynamic _) => http.Response('', 500));
  }

  Future<String?> banUser({required String batchId, required String userId, String? reason}) async {
    return _upsertBanState(
      batchId: batchId,
      userId: userId,
      isBanned: true,
      isRestricted: false,
      reason: reason,
    );
  }

  Future<String?> unbanUser({required String batchId, required String userId}) async {
    return _upsertBanState(
      batchId: batchId,
      userId: userId,
      isBanned: false,
      isRestricted: false,
    );
  }

  Future<String?> restrictUser({required String batchId, required String userId, String? reason}) async {
    return _upsertBanState(
      batchId: batchId,
      userId: userId,
      isBanned: false,
      isRestricted: true,
      reason: reason,
    );
  }

  Future<String?> unrestrictUser({required String batchId, required String userId}) async {
    return _upsertBanState(
      batchId: batchId,
      userId: userId,
      isBanned: false,
      isRestricted: false,
    );
  }

  Future<String?> _upsertBanState({
    required String batchId,
    required String userId,
    required bool isBanned,
    required bool isRestricted,
    String? reason,
  }) async {
    final url = ApiConfig.uri('/batch_chat_bans', {
      'on_conflict': 'batch_id,user_id',
    });

    final response = await http.post(
      url,
      headers: {
        'apikey': SupabaseConfig.apiKey,
        'Authorization': 'Bearer ${SupabaseConfig.apiKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation,resolution=merge-duplicates',
      },
      body: jsonEncode({
        'batch_id': batchId,
        'user_id': userId,
        'is_banned': isBanned,
        'is_restricted': isRestricted,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return 'Failed to update user restrictions';
    }
    if (userId == await _getUserId()) {
      _isBanned = isBanned;
      _isRestricted = isRestricted;
    }
    notifyListeners();
    return null;
  }
}
