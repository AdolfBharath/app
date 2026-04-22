import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

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

  factory BatchChatAuthor.fromJson(Map<String, dynamic> json) {
    return BatchChatAuthor(
      id: json['author_id']?.toString() ?? json['id']?.toString() ?? '',
      name: (json['author_name'] ?? json['name'] ?? '').toString(),
      role: (json['author_role'] ?? json['role'] ?? 'student').toString(),
      username: (json['author_username'] ?? json['username'])?.toString(),
    );
  }
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

  factory BatchChatReply.fromJson(Map<String, dynamic> json) {
    return BatchChatReply(
      id: json['id'].toString(),
      postId: json['post_id'].toString(),
      parentReplyId: json['parent_reply_id']?.toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.tryParse(json['deleted_at']?.toString() ?? ''),
      author: BatchChatAuthor.fromJson(json),
    );
  }
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

  factory BatchChatPost.fromJson(Map<String, dynamic> json) {
    return BatchChatPost(
      id: json['id'].toString(),
      batchId: json['batch_id'].toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.tryParse(json['deleted_at']?.toString() ?? ''),
      author: BatchChatAuthor.fromJson(json),
      upvotes: (json['upvotes'] is int)
          ? json['upvotes'] as int
          : int.tryParse(json['upvotes']?.toString() ?? '0') ?? 0,
      didUpvote: json['did_upvote'] == true,
    );
  }
}

class ChatProvider extends ChangeNotifier {
  ChatProvider() : _api = ApiClient();

  final ApiClient _api;

  bool _loading = false;
  String? _error;
  bool _isBanned = false;
  String? _batchName;
  final List<BatchChatPost> _posts = [];

  bool get loading => _loading;
  String? get error => _error;
  bool get isBanned => _isBanned;
  String? get batchName => _batchName;
  UnmodifiableListView<BatchChatPost> get posts => UnmodifiableListView(_posts);

  static const List<String> _badWords = <String>[
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'dick',
    'cunt',
  ];

  bool _containsBadWords(String text) {
    final t = text.toLowerCase();
    for (final w in _badWords) {
      final re = RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false);
      if (re.hasMatch(t)) return true;
    }
    return false;
  }

  void clearState() {
    _loading = false;
    _error = null;
    _isBanned = false;
    _batchName = null;
    _posts.clear();
    notifyListeners();
  }

  Future<void> loadBatchChat(String batchId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final json = await _api.getJsonObject('/batches/$batchId/chat');

      _isBanned = json['isBanned'] == true;
      _batchName = (json['batch'] is Map)
          ? (json['batch']['name']?.toString())
          : null;

      final postsJson = (json['posts'] as List? ?? const []).cast<dynamic>();
      final repliesJson = (json['replies'] as List? ?? const []).cast<dynamic>();

      final posts = postsJson
          .where((e) => e is Map)
          .map((e) => BatchChatPost.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final replies = repliesJson
          .where((e) => e is Map)
          .map((e) => BatchChatReply.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final repliesByPost = <String, List<BatchChatReply>>{};
      for (final r in replies) {
        (repliesByPost[r.postId] ??= []).add(r);
      }

      for (final p in posts) {
        p.replies
          ..clear()
          ..addAll(repliesByPost[p.id] ?? const <BatchChatReply>[]);
      }

      _posts
        ..clear()
        ..addAll(posts);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> createPost(String batchId, String content) async {
    final text = content.trim();
    if (text.isEmpty) return 'Message is empty';
    if (text.length > 1000) return 'Message is too long';
    if (_containsBadWords(text)) return 'Inappropriate content not allowed';

    try {
      await _api.postJson('/batches/$batchId/chat/posts', {'content': text});
      await loadBatchChat(batchId);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> createReply({
    required String batchId,
    required String postId,
    required String content,
    String? parentReplyId,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return 'Reply is empty';
    if (text.length > 1000) return 'Reply is too long';
    if (_containsBadWords(text)) return 'Inappropriate content not allowed';

    try {
      await _api.postJson(
        '/batches/$batchId/chat/posts/$postId/replies',
        {
          'content': text,
          if (parentReplyId != null) 'parentReplyId': parentReplyId,
        },
      );
      await loadBatchChat(batchId);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> toggleUpvote({required String batchId, required String postId}) async {
    try {
      final json = await _api.postJson(
        '/batches/$batchId/chat/posts/$postId/upvote',
        const <String, dynamic>{},
      );

      final didUpvote = json['didUpvote'] == true;
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final p = _posts[postIndex];
        if (didUpvote && !p.didUpvote) p.upvotes += 1;
        if (!didUpvote && p.didUpvote) p.upvotes = (p.upvotes - 1).clamp(0, 1 << 30);
        p.didUpvote = didUpvote;
        notifyListeners();
      }
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> deletePost({required String batchId, required String postId}) async {
    try {
      await _api.deleteJson('/batches/$batchId/chat/posts/$postId');
      await loadBatchChat(batchId);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> deleteReply({required String batchId, required String replyId}) async {
    try {
      await _api.deleteJson('/batches/$batchId/chat/replies/$replyId');
      await loadBatchChat(batchId);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> banUser({required String batchId, required String userId, String? reason}) async {
    try {
      await _api.postJson('/batches/$batchId/chat/ban', {
        'userId': userId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
      await loadBatchChat(batchId);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> unbanUser({required String batchId, required String userId}) async {
    try {
      await _api.postJson('/batches/$batchId/chat/unban', {'userId': userId});
      await loadBatchChat(batchId);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('403')) return 'You are banned from this chat';
    if (raw.contains('Inappropriate')) return 'Inappropriate content not allowed';
    return raw;
  }
}
