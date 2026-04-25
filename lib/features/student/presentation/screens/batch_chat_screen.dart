import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../models/user.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/chat_provider.dart';

class BatchChatScreen extends StatefulWidget {
  const BatchChatScreen({
    super.key,
    required this.batchId,
    this.batchName,
  });

  final String batchId;
  final String? batchName;

  @override
  State<BatchChatScreen> createState() => _BatchChatScreenState();
}

class _BatchChatScreenState extends State<BatchChatScreen> {
  final _postController = TextEditingController();
  final _replyController = TextEditingController();
  final _postFocus = FocusNode();
  final _replyFocus = FocusNode();

  String? _activeReplyPostId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadBatchChat(widget.batchId);
    });
  }

  @override
  void dispose() {
    _postController.dispose();
    _replyController.dispose();
    _postFocus.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  bool _isModerator(UserRole? role) {
    return role == UserRole.admin || role == UserRole.mentor;
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ADMIN';
      case 'mentor':
        return 'MENTOR';
      default:
        return 'STUDENT';
    }
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
      ),
    );
  }

  Future<void> _submitPost() async {
    final chat = context.read<ChatProvider>();
    if (chat.isBanned) {
      _showError('You are banned from this chat');
      return;
    }
    final text = _postController.text;

    final err = await chat.createPost(widget.batchId, text);
    if (err != null) {
      _showError(err);
      return;
    }

    _postController.clear();
    _postFocus.unfocus();
  }

  Future<void> _submitReply(String postId) async {
    final chat = context.read<ChatProvider>();
    if (chat.isBanned) {
      _showError('You are banned from this chat');
      return;
    }
    final text = _replyController.text;

    final err = await chat.createReply(
      batchId: widget.batchId,
      postId: postId,
      content: text,
    );
    if (err != null) {
      _showError(err);
      return;
    }

    _replyController.clear();
    _replyFocus.unfocus();
    setState(() {
      _activeReplyPostId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final auth = context.watch<AuthProvider>();
    final role = auth.currentRole;
    final currentUserId = auth.currentUser?.id;

    final chat = context.watch<ChatProvider>();

    final resolvedBatchName = widget.batchName?.trim().isNotEmpty == true
      ? widget.batchName!.trim()
      : (chat.batchName?.trim().isNotEmpty == true ? chat.batchName!.trim() : null);

    final isModerator = _isModerator(role);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batch Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
            ),
            if (resolvedBatchName != null)
              Text(
                resolvedBatchName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withAlpha(170),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (chat.isBanned)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.error.withAlpha(45)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: scheme.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are banned from this chat',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (chat.error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chat.error!,
                        style: GoogleFonts.poppins(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context
                          .read<ChatProvider>()
                          .loadBatchChat(widget.batchId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context
                    .read<ChatProvider>()
                    .loadBatchChat(widget.batchId),
                child: chat.loading && chat.posts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : chat.posts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 42,
                                    color: scheme.onSurface.withAlpha(120),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No discussions yet',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chat.isBanned
                                        ? 'You can only read this thread while banned.'
                                        : 'Ask a question to start the batch discussion.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: scheme.onSurface.withAlpha(170),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: chat.posts.length,
                        itemBuilder: (context, index) {
                          final post = chat.posts[index];

                          final isNew = DateTime.now().difference(post.createdAt) <
                              const Duration(seconds: 20);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PostCard(
                              post: post,
                              timeLabel: _timeAgo(post.createdAt),
                              isNew: isNew,
                              isModerator: isModerator,
                              isMine: currentUserId != null &&
                                  post.author.id == currentUserId,
                              roleLabel: _roleLabel(post.author.role),
                              activeReply: _activeReplyPostId == post.id,
                              replyController: _replyController,
                              replyFocus: _replyFocus,
                                formatTimeAgo: _timeAgo,
                              onReplyTap: chat.isBanned
                                  ? null
                                  : () {
                                      setState(() {
                                        if (_activeReplyPostId == post.id) {
                                          _activeReplyPostId = null;
                                        } else {
                                          _activeReplyPostId = post.id;
                                        }
                                      });
                                      if (_activeReplyPostId == post.id) {
                                        _replyFocus.requestFocus();
                                      } else {
                                        _replyFocus.unfocus();
                                      }
                                    },
                              onSubmitReply: chat.isBanned
                                  ? null
                                  : () => _submitReply(post.id),
                              onUpvote: () async {
                                final err = await context
                                    .read<ChatProvider>()
                                    .toggleUpvote(
                                      batchId: widget.batchId,
                                      postId: post.id,
                                    );
                                if (err != null) _showError(err);
                              },
                              onDeletePost: isModerator
                                  ? () async {
                                      final ok = await _confirm(
                                        context,
                                        title: 'Delete post?',
                                        message:
                                            'This will remove the post from the discussion.',
                                      );
                                      if (ok != true) return;
                                      final err = await context
                                          .read<ChatProvider>()
                                          .deletePost(
                                            batchId: widget.batchId,
                                            postId: post.id,
                                          );
                                      if (err != null) _showError(err);
                                    }
                                  : null,
                              onBanUser: isModerator
                                  ? () async {
                                      final err = await context
                                          .read<ChatProvider>()
                                          .banUser(
                                            batchId: widget.batchId,
                                            userId: post.author.id,
                                          );
                                      if (err != null) _showError(err);
                                    }
                                  : null,
                              onUnbanUser: isModerator
                                  ? () async {
                                      final err = await context
                                          .read<ChatProvider>()
                                          .unbanUser(
                                            batchId: widget.batchId,
                                            userId: post.author.id,
                                          );
                                      if (err != null) _showError(err);
                                    }
                                  : null,
                              onDeleteReply: isModerator
                                  ? (replyId) async {
                                      final ok = await _confirm(
                                        context,
                                        title: 'Delete reply?',
                                        message:
                                            'This will remove the reply from the discussion.',
                                      );
                                      if (ok != true) return;
                                      final err = await context
                                          .read<ChatProvider>()
                                          .deleteReply(
                                            batchId: widget.batchId,
                                            replyId: replyId,
                                          );
                                      if (err != null) _showError(err);
                                    }
                                  : null,
                              onBanReplyUser: isModerator
                                  ? (userId) async {
                                      final err = await context
                                          .read<ChatProvider>()
                                          .banUser(
                                            batchId: widget.batchId,
                                            userId: userId,
                                          );
                                      if (err != null) _showError(err);
                                    }
                                  : null,
                              onUnbanReplyUser: isModerator
                                  ? (userId) async {
                                      final err = await context
                                          .read<ChatProvider>()
                                          .unbanUser(
                                            batchId: widget.batchId,
                                            userId: userId,
                                          );
                                      if (err != null) _showError(err);
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ),
            _Composer(
              controller: _postController,
              focusNode: _postFocus,
              enabled: !chat.isBanned,
              banned: chat.isBanned,
              onSubmit: _submitPost,
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
      content: Text(message, style: GoogleFonts.poppins()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.banned,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool banned;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.onSurface.withAlpha(10)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banned)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.block_rounded, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are banned from this chat',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ask a question...',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.onSurface.withAlpha(14),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.onSurface.withAlpha(14),
                      ),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: enabled ? onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Post',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.timeLabel,
    required this.isNew,
    required this.isModerator,
    required this.isMine,
    required this.roleLabel,
    required this.activeReply,
    required this.replyController,
    required this.replyFocus,
    required this.formatTimeAgo,
    required this.onReplyTap,
    required this.onSubmitReply,
    required this.onUpvote,
    required this.onDeletePost,
    required this.onBanUser,
    required this.onUnbanUser,
    required this.onDeleteReply,
    required this.onBanReplyUser,
    required this.onUnbanReplyUser,
  });

  final BatchChatPost post;
  final String timeLabel;
  final bool isNew;
  final bool isModerator;
  final bool isMine;
  final String roleLabel;

  final bool activeReply;
  final TextEditingController replyController;
  final FocusNode replyFocus;
  final String Function(DateTime) formatTimeAgo;
  final VoidCallback? onReplyTap;
  final VoidCallback? onSubmitReply;

  final VoidCallback onUpvote;
  final VoidCallback? onDeletePost;
  final VoidCallback? onBanUser;
  final VoidCallback? onUnbanUser;

  final Future<void> Function(String replyId)? onDeleteReply;
  final Future<void> Function(String userId)? onBanReplyUser;
  final Future<void> Function(String userId)? onUnbanReplyUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final borderColor = isNew
        ? scheme.primary.withAlpha(90)
        : scheme.onSurface.withAlpha(14);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: onUpvote,
                      borderRadius: BorderRadius.circular(999),
                      child: Icon(
                        post.didUpvote
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_up_outlined,
                        size: 22,
                        color: post.didUpvote
                            ? scheme.primary
                            : scheme.onSurface.withAlpha(170),
                      ),
                    ),
                    Text(
                      '${post.upvotes}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: post.didUpvote ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.primary.withAlpha(14),
                          child: Icon(Icons.person_rounded, color: scheme.primary, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.author.username?.trim().isNotEmpty == true
                                ? post.author.username!
                                : post.author.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (roleLabel != 'STUDENT')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleLabel == 'ADMIN'
                                  ? scheme.errorContainer
                                  : scheme.tertiary.withAlpha(18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: roleLabel == 'ADMIN'
                                    ? scheme.error.withAlpha(50)
                                    : scheme.tertiary.withAlpha(50),
                              ),
                            ),
                            child: Text(
                              roleLabel,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: roleLabel == 'ADMIN'
                                    ? scheme.onErrorContainer
                                    : scheme.tertiary,
                              ),
                            ),
                          ),
                        if (isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.primary.withAlpha(16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
              if (isModerator && !isMine)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete' && onDeletePost != null) onDeletePost!();
                    if (value == 'ban' && onBanUser != null) onBanUser!();
                    if (value == 'unban' && onUnbanUser != null) onUnbanUser!();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'delete', child: Text('Delete post')),
                    const PopupMenuItem(value: 'ban', child: Text('Ban user')),
                    const PopupMenuItem(value: 'unban', child: Text('Unban user')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.isDeleted ? '[deleted]' : post.content,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: post.isDeleted
                  ? scheme.onSurface.withAlpha(215)
                  : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onReplyTap,
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: Text('Reply', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (post.replies.isNotEmpty)
                Text(
                  '${post.replies.length} replies',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withAlpha(200),
                  ),
                ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: !activeReply
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: replyController,
                            focusNode: replyFocus,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Write a reply…',
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: scheme.onSurface.withAlpha(14),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: scheme.onSurface.withAlpha(14),
                                ),
                              ),
                            ),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: onSubmitReply,
                            child: Text(
                              'Send',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (post.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              children: post.replies.map((r) {
                final replyRole = r.author.role.toLowerCase();
                final replyRoleLabel = replyRole == 'admin'
                    ? 'ADMIN'
                    : (replyRole == 'mentor' ? 'MENTOR' : '');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    margin: const EdgeInsets.only(left: 18),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.onSurface.withAlpha(12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.author.username?.trim().isNotEmpty == true
                                          ? r.author.username!
                                          : r.author.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (replyRoleLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: replyRoleLabel == 'ADMIN'
                                            ? scheme.errorContainer
                                            : scheme.tertiary.withAlpha(18),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        replyRoleLabel,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          color: replyRoleLabel == 'ADMIN'
                                              ? scheme.onErrorContainer
                                              : scheme.tertiary,
                                        ),
                                      ),
                                    ),
                                  if (isModerator)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'delete' && onDeleteReply != null) {
                                          onDeleteReply!(r.id);
                                        }
                                        if (value == 'ban' && onBanReplyUser != null) {
                                          onBanReplyUser!(r.author.id);
                                        }
                                        if (value == 'unban' && onUnbanReplyUser != null) {
                                          onUnbanReplyUser!(r.author.id);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'delete', child: Text('Delete reply')),
                                        const PopupMenuItem(value: 'ban', child: Text('Ban user')),
                                        const PopupMenuItem(value: 'unban', child: Text('Unban user')),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatTimeAgo(r.createdAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface.withAlpha(170),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.isDeleted ? '[deleted]' : r.content,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: r.isDeleted
                                      ? scheme.onSurface.withAlpha(215)
                                      : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
