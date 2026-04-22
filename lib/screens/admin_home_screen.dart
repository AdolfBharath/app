import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'admin_home_dashboard.dart';
import 'admin_profile_screen.dart';
import 'login_screen.dart';
import 'manage_batch_screen.dart';
import 'manage_course_screen.dart';
import 'manage_user_screen.dart';
import 'marketplace_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  static const routeName = '/admin/home';

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 2;
  bool _initialized = false;
  bool _isLoadingInbox = false;
  int _adminInboxCount = 0;
  List<Map<String, dynamic>> _adminInboxItems = const [];

  final ApiService _apiService = ApiService.instance;

  late final List<Widget> _pages = <Widget>[
    const ManageUserScreen(),
    const ManageCourseScreen(),
    const AdminHomeDashboard(),
    const ManageBatchScreen(),
    const AdminProfileScreen(),
  ];

  static const List<String> _sectionLabels = [
    'Manage Users',
    'Courses',
    'Dashboard',
    'Batches',
    'Profile',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final courses = Provider.of<CourseProvider>(context, listen: false);
    final batches = Provider.of<BatchProvider>(context, listen: false);

    Future.microtask(() async {
      if (!mounted) return;

      if (!auth.isLoggedIn || auth.currentRole != UserRole.admin) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
        return;
      }

      await Future.wait([
        auth.loadUsers(),
        courses.loadCourses(),
        batches.loadBatches(),
      ]);

      await _loadAdminInbox();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _logout() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.logout();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(MarketplaceScreen.routeName, (route) => false);
  }

  Future<void> _loadAdminInbox({bool showErrorSnack = false}) async {
    if (_isLoadingInbox) {
      return;
    }

    setState(() {
      _isLoadingInbox = true;
    });

    try {
      final notifications = await _apiService.getAdminInboxNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _adminInboxItems = notifications;
        _adminInboxCount = notifications.length;
      });
    } catch (error) {
      if (mounted && showErrorSnack) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInbox = false;
        });
      }
    }
  }

  Future<void> _openAdminInboxSheet() async {
    await _loadAdminInbox(showErrorSnack: true);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AdminInboxSheet(
          isLoading: _isLoadingInbox,
          notifications: _adminInboxItems,
          onRefresh: () => _loadAdminInbox(showErrorSnack: true),
        );
      },
    );
  }

  Future<void> _openAnnouncementComposer() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String targetGroup = 'both';
    bool sending = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
            Future<void> send() async {
              final message = messageController.text.trim();
              final title = titleController.text.trim();
              final messenger = ScaffoldMessenger.of(this.context);

              if (message.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Announcement message is required.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                sending = true;
              });

              var closedDialog = false;

              try {
                await _apiService.sendAnnouncement(
                  title: title.isEmpty ? 'Announcement' : title,
                  message: message,
                  targetGroup: targetGroup,
                );

                if (!mounted) {
                  return;
                }

                closedDialog = true;
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Announcement sent.')),
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                messenger.showSnackBar(SnackBar(content: Text(error.toString())));
              } finally {
                if (mounted && !closedDialog) {
                  try {
                    setDialogState(() {
                      sending = false;
                    });
                  } catch (_) {
                    // Dialog state may already be disposed if the route closed externally.
                  }
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Create Announcement',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Announcement message',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: targetGroup,
                      decoration: const InputDecoration(labelText: 'Audience'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'students',
                          child: Text('Students'),
                        ),
                        DropdownMenuItem(
                          value: 'mentors',
                          child: Text('Mentors'),
                        ),
                        DropdownMenuItem(value: 'admins', child: Text('Admins')),
                        DropdownMenuItem(value: 'both', child: Text('Both')),
                      ],
                      onChanged: sending
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                targetGroup = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending ? null : send,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFEFF6FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(84),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: _AdminTopBar(
              sectionLabel: _sectionLabels[_currentIndex],
              inboxCount: _adminInboxCount,
              onAnnouncementTap: _openAnnouncementComposer,
              onInboxTap: _openAdminInboxSheet,
              onProfileTap: () => _onItemTapped(4),
              onLogout: _logout,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F8FF), Color(0xFFEAF3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _AdminLmsNavigationBar(
            currentIndex: _currentIndex,
            onItemSelected: _onItemTapped,
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.sectionLabel,
    required this.inboxCount,
    required this.onAnnouncementTap,
    required this.onInboxTap,
    required this.onProfileTap,
    required this.onLogout,
  });

  final String sectionLabel;
  final int inboxCount;
  final VoidCallback onAnnouncementTap;
  final VoidCallback onInboxTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final adminName = auth.currentUser?.name ?? 'Admin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/favicon.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jenovate LMS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.1,
                        ),
                      ),
                      Text(
                        sectionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BadgeActionIcon(
            icon: Icons.campaign_outlined,
            onTap: onAnnouncementTap,
            badgeCount: 0,
          ),
          const SizedBox(width: 6),
          _BadgeActionIcon(
            icon: Icons.notifications_none_rounded,
            onTap: onInboxTap,
            badgeCount: inboxCount,
          ),
          const SizedBox(width: 6),
          _BadgeActionIcon(
            icon: Icons.logout_rounded,
            onTap: onLogout,
            badgeCount: 0,
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFDCEBFF),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF3B82F6),
                child: Text(
                  adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeActionIcon extends StatelessWidget {
  const _BadgeActionIcon({
    required this.icon,
    required this.onTap,
    required this.badgeCount,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 17, color: const Color(0xFF334155)),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminLmsNavigationBar extends StatelessWidget {
  const _AdminLmsNavigationBar({
    required this.currentIndex,
    required this.onItemSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white.withOpacity(0.92),
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF94A3B8),
                );
              }),
            ),
            child: NavigationBar(
              height: 82,
              selectedIndex: currentIndex,
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xFF2563EB),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: onItemSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded, color: Colors.white),
                  label: 'Users',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                  ),
                  label: 'Courses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.layers_outlined),
                  selectedIcon: Icon(Icons.layers_rounded, color: Colors.white),
                  label: 'Batches',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded, color: Colors.white),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminInboxSheet extends StatelessWidget {
  const _AdminInboxSheet({
    required this.isLoading,
    required this.notifications,
    required this.onRefresh,
  });

  final bool isLoading;
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFBFDBFE),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Text(
                  'Admin Notifications',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                ? Center(
                    child: Text(
                      'No updates from admins or mentors.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final sender = (item['sender'] ?? 'System').toString();
                      final title = (item['title'] ?? 'Notification')
                          .toString();
                      final message = (item['message'] ?? '').toString();
                      final senderRole = (item['sender_role'] ?? 'unknown')
                          .toString();
                      final createdAt = (item['created_at'] ?? '')
                          .toString()
                          .trim();

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    senderRole,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'From $sender${createdAt.isEmpty ? '' : ' • $createdAt'}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
