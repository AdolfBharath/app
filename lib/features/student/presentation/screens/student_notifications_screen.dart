import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/student_provider.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  String _selectedTab = 'All';
  final List<String> _tabs = [
    'All',
    'Unread',
    'Courses',
    'Assignments',
    'Payments',
    'Live'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.search,
                        color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined,
                        color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: _buildFilterTabs(isDark),
                ),
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: () =>
                context.read<StudentProvider>().fetchNotifications(),
            color: const Color(0xFF6366F1), // Indigo
            child: Consumer<StudentProvider>(
              builder: (context, student, _) {
                final allNotifications = student.notifications;
                final filteredNotifications = allNotifications.where((n) {
                  if (_selectedTab == 'All') return true;
                  if (_selectedTab == 'Unread') return !n.read;
                  if (_selectedTab == 'Courses') return n.type == 'course';
                  if (_selectedTab == 'Assignments') return n.type == 'assignment';
                  if (_selectedTab == 'Payments') return n.type == 'payment';
                  if (_selectedTab == 'Live') return n.type == 'live_class';
                  return true;
                }).toList();

                if (student.isLoading && allNotifications.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                    ),
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
                        context.read<StudentProvider>().markNotificationRead(n.id);
                      },
                      onDelete: () {
                        context.read<StudentProvider>().deleteNotification(n.id);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isActive
                      ? null
                      : (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
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
          'You’ll see updates about courses,\nassignments, and live classes here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: ElevatedButton(
            onPressed: () {
              // Explore Courses action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
              textStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Explore Courses'),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final StudentNotification notification;
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
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              width: 1,
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
              // Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: typeData.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: typeData.color.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  typeData.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: notification.read
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
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
              if (!notification.read) ...[
                const SizedBox(width: 12),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
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
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
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
          const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 10,
          ),
        ],
      ),
    );
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

class _TypeData {
  final IconData icon;
  final Color color;
  final Gradient gradient;

  _TypeData({
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
