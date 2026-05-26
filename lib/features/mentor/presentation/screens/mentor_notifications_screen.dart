import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/mentor_provider.dart';

class MentorNotificationsScreen extends StatefulWidget {
  const MentorNotificationsScreen({super.key});

  @override
  State<MentorNotificationsScreen> createState() =>
      _MentorNotificationsScreenState();
}

class _MentorNotificationsScreenState extends State<MentorNotificationsScreen> {
  String _selectedTab = 'All';
  final _searchController = TextEditingController();
  final List<String> _tabs = [
    'All',
    'Unread',
    'Courses',
    'Assignments',
    'Payments',
    'Live',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MentorProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF4F7FB),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF4F7FB),
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 84,
                titleSpacing: 16,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mentor Inbox',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Consumer<MentorProvider>(
                      builder: (context, provider, child) {
                        final unread = provider.notifications
                            .where((n) => !n.read)
                            .length;
                        return Text(
                          unread == 0
                              ? 'All caught up'
                              : '$unread unread update${unread == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  IconButton.filledTonal(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                    onPressed: () => context.read<MentorProvider>().loadAll(),
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(116),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _SearchBox(
                          controller: _searchController,
                          isDark: isDark,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      _buildFilterTabs(isDark),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: () => context.read<MentorProvider>().loadAll(),
            color: const Color(0xFF6366F1), // Indigo
            child: Consumer<MentorProvider>(
              builder: (context, provider, _) {
                final allNotifications = provider.notifications;
                final query = _searchController.text.trim().toLowerCase();
                final filteredNotifications = allNotifications
                    .where((n) {
                      if (_selectedTab == 'All') return true;
                      if (_selectedTab == 'Unread') return !n.read;
                      if (_selectedTab == 'Courses') return n.type == 'course';
                      if (_selectedTab == 'Assignments') {
                        return n.type == 'assignment';
                      }
                      if (_selectedTab == 'Payments') {
                        return n.type == 'payment';
                      }
                      if (_selectedTab == 'Live') return n.type == 'live_class';
                      return true;
                    })
                    .where((n) {
                      if (query.isEmpty) return true;
                      return n.sender.toLowerCase().contains(query) ||
                          n.message.toLowerCase().contains(query) ||
                          n.type.toLowerCase().contains(query) ||
                          n.priority.toLowerCase().contains(query);
                    })
                    .toList();

                if (provider.isLoading && allNotifications.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  );
                }

                if (filteredNotifications.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredNotifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final n = filteredNotifications[index];
                    return _NotificationCard(
                      notification: n,
                      isDark: isDark,
                      onMarkRead: () {
                        context.read<MentorProvider>().markNotificationRead(
                          n.id,
                        );
                      },
                      onDelete: () {
                        context.read<MentorProvider>().deleteNotification(n.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isActive = _selectedTab == tab;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = tab;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? null
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? Colors.transparent
                        : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFD8E0EA)),
                  ),
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: GoogleFonts.inter(
                      color: isActive
                          ? Colors.white
                          : (isDark ? const Color(0xFFCBD5E1) : Colors.black54),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'No Notifications Yet',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You will see updates from students,\ncourses, and batches here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFD8E0EA);
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: 'Search student updates',
        hintStyle: GoogleFonts.inter(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final MentorNotification notification;
  final bool isDark;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeData = _getTypeData(notification.type);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final unreadColor = isDark
        ? const Color(0xFF6366F1).withAlpha(20)
        : const Color(0xFFEEF2FF);

    return Dismissible(
      key: ValueKey(notification.id),
      background: _buildSwipeBackground(
        color: const Color(0xFFEF4444),
        icon: Icons.delete_outline,
        alignment: Alignment.centerLeft,
        isDark: isDark,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: const Color(0xFF10B981),
        icon: Icons.check,
        alignment: Alignment.centerRight,
        isDark: isDark,
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onMarkRead();
        } else {
          onDelete();
        }
      },
      child: GestureDetector(
        onTap: onMarkRead,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.read ? cardColor : unreadColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.read
                  ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                  : const Color(0xFF2563EB).withAlpha(120),
              width: notification.read ? 1 : 1.4,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: typeData.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: typeData.color.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(typeData.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.sender,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: notification.read
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _NotificationMenu(
                          isDark: isDark,
                          isRead: notification.read,
                          onMarkRead: onMarkRead,
                          onDelete: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          label: _labelForType(notification.type),
                          color: typeData.color,
                          isDark: isDark,
                        ),
                        if (notification.priority.trim().isNotEmpty)
                          _MetaChip(
                            label: notification.priority.toUpperCase(),
                            color: _priorityColor(notification.priority),
                            isDark: isDark,
                          ),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    if (_hasCtaButton(notification.type)) ...[
                      const SizedBox(height: 12),
                      _buildCtaButton(notification.type, isDark),
                    ],
                  ],
                ),
              ),
              if (!notification.read)
                Container(
                  margin: const EdgeInsets.only(top: 4, left: 10),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  bool _hasCtaButton(String type) {
    return ['live_class', 'assignment', 'course', 'payment'].contains(type);
  }

  Widget _buildCtaButton(String type, bool isDark) {
    String label = 'View';
    switch (type) {
      case 'live_class':
        label = 'Join Now';
        break;
      case 'assignment':
        label = 'View Task';
        break;
      case 'course':
        label = 'Continue';
        break;
      case 'payment':
        label = 'Invoice';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
        ],
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'live_class':
        return 'Live';
      case 'assignment':
        return 'Assignment';
      case 'payment':
        return 'Payment';
      case 'course':
        return 'Course';
      case 'message':
        return 'Message';
      case 'certificate':
        return 'Certificate';
      default:
        return 'Update';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  _TypeData _getTypeData(String type) {
    switch (type) {
      case 'success':
      case 'payment':
        return _TypeData(
          icon: Icons.wallet_outlined,
          color: const Color(0xFF10B981),
          gradient: const LinearGradient(
            colors: [Color(0xFF34D399), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'warning':
      case 'assignment':
        return _TypeData(
          icon: Icons.assignment_outlined,
          color: const Color(0xFFF59E0B),
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'error':
        return _TypeData(
          icon: Icons.error_outline,
          color: const Color(0xFFEF4444),
          gradient: const LinearGradient(
            colors: [Color(0xFFF87171), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'course':
        return _TypeData(
          icon: Icons.menu_book_outlined,
          color: const Color(0xFF3B82F6),
          gradient: const LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'live_class':
        return _TypeData(
          icon: Icons.videocam_outlined,
          color: const Color(0xFFA855F7),
          gradient: const LinearGradient(
            colors: [Color(0xFFC084FC), Color(0xFF7E22CE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'certificate':
        return _TypeData(
          icon: Icons.workspace_premium_outlined,
          color: const Color(0xFFEAB308),
          gradient: const LinearGradient(
            colors: [Color(0xFFFACC15), Color(0xFFCA8A04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'message':
        return _TypeData(
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF06B6D4),
          gradient: const LinearGradient(
            colors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      default:
        return _TypeData(
          icon: Icons.notifications_outlined,
          color: const Color(0xFF64748B),
          gradient: const LinearGradient(
            colors: [Color(0xFF94A3B8), Color(0xFF475569)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${time.day}/${time.month}/${time.year}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 38 : 24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(isDark ? 80 : 50)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : color,
        ),
      ),
    );
  }
}

class _NotificationMenu extends StatelessWidget {
  const _NotificationMenu({
    required this.isDark,
    required this.isRead,
    required this.onMarkRead,
    required this.onDelete,
  });

  final bool isDark;
  final bool isRead;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Notification actions',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
      ),
      onSelected: (value) {
        if (value == 'read') onMarkRead();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (!isRead)
          const PopupMenuItem(value: 'read', child: Text('Mark as read')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

class _TypeData {
  final IconData icon;
  final Color color;
  final Gradient gradient;

  _TypeData({required this.icon, required this.color, required this.gradient});
}
