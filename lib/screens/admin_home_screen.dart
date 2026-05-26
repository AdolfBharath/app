import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../providers/shop_provider.dart';
import '../services/api_service.dart';
import 'admin_home_dashboard.dart';
import 'admin_profile_screen.dart';
import 'login_screen.dart';
import 'manage_batch_screen.dart';
import 'manage_course_screen.dart';
import 'manage_user_screen.dart';
import 'marketplace_screen.dart';
import '../widgets/animated_lms_nav_bar.dart';

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
    final shop = Provider.of<ShopProvider>(context, listen: false);

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
        shop.fetchShopItems(),
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
      await _apiService.deleteExpiredNotifications().catchError((_) {});
      final notifications = await _apiService.getAdminInboxNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _adminInboxItems = notifications;
        _adminInboxCount = notifications.where((n) => n['read'] != true).length;
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
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            elevation: 16,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 760
                  ? 680
                  : MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.78,
              child: SafeArea(
                child: _AdminInboxSheet(
                  isLoading: _isLoadingInbox,
                  notifications: _adminInboxItems,
                  onRefresh: () => _loadAdminInbox(showErrorSnack: true),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.96,
            end: 1,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  Future<void> _openAnnouncementComposer() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    DateTime? expiresOn;
    String audience = 'both';
    String priority = 'normal';
    String? batchId;
    String? courseId;
    bool sending = false;

    try {
      final batchProvider = context.read<BatchProvider>();
      final courseProvider = context.read<CourseProvider>();
      if (batchProvider.batches.isEmpty) {
        await batchProvider.loadBatches();
      }
      if (courseProvider.courses.isEmpty) {
        await courseProvider.loadCourses();
      }
      if (!mounted) return;

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
                  if (audience == 'batch' && batchId != null) {
                    await _apiService.sendBatchAnnouncement(
                      batchId: batchId!,
                      title: title.isEmpty ? 'Announcement' : title,
                      message: message,
                    );
                  } else {
                    await _apiService.sendAnnouncement(
                      title: title.isEmpty ? 'Announcement' : title,
                      message: [
                        message,
                        if (priority != 'normal')
                          '\nPriority: ${_labelForPriority(priority)}',
                        if (expiresOn != null)
                          'Expires on: ${_formatDate(expiresOn!)}',
                        if (courseId != null)
                          'Course: ${courseProvider.getById(courseId!)?.title ?? courseId}',
                      ].join('\n'),
                      targetGroup: _targetGroupForAudience(audience),
                    );
                  }

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

                  messenger.showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
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

              final batches = batchProvider.batches;
              final courses = courseProvider.courses;

              return Dialog(
                insetPadding: const EdgeInsets.all(18),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(30, 24, 30, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Create Announcement',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: sending
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _AnnouncementLabel('Title'),
                        const SizedBox(height: 8),
                        _AnnouncementTextField(
                          controller: titleController,
                          hintText: 'Optional headline',
                          enabled: !sending,
                        ),
                        const SizedBox(height: 20),
                        _AnnouncementLabel('Announcement message'),
                        const SizedBox(height: 8),
                        _AnnouncementTextField(
                          controller: messageController,
                          hintText: 'Write the announcement...',
                          enabled: !sending,
                          minLines: 4,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _AnnouncementDropdown<String>(
                                label: 'Audience',
                                value: audience,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'both',
                                    child: Text('Students and mentors'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'students',
                                    child: Text('Students only'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mentors',
                                    child: Text('Mentors only'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'batch',
                                    child: Text('Specific batch'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'course',
                                    child: Text('Specific course'),
                                  ),
                                ],
                                onChanged: sending
                                    ? null
                                    : (value) => setDialogState(() {
                                        audience = value ?? 'both';
                                      }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AnnouncementDropdown<String>(
                                label: 'Priority',
                                value: priority,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'normal',
                                    child: Text('Normal'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'important',
                                    child: Text('Important'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'urgent',
                                    child: Text('Urgent'),
                                  ),
                                ],
                                onChanged: sending
                                    ? null
                                    : (value) => setDialogState(() {
                                        priority = value ?? 'normal';
                                      }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _AnnouncementDropdown<String?>(
                                label: 'Batch target',
                                value: batchId,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('No batch target'),
                                  ),
                                  ...batches.map(
                                    (batch) => DropdownMenuItem<String?>(
                                      value: batch.id,
                                      child: Text(
                                        batch.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: sending
                                    ? null
                                    : (value) =>
                                          setDialogState(() => batchId = value),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AnnouncementDropdown<String?>(
                                label: 'Course target',
                                value: courseId,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('No course target'),
                                  ),
                                  ...courses.map(
                                    (course) => DropdownMenuItem<String?>(
                                      value: course.id,
                                      child: Text(
                                        course.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: sending
                                    ? null
                                    : (value) => setDialogState(
                                        () => courseId = value,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _AnnouncementLabel('Expires on'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: sending
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365 * 2),
                                    ),
                                    initialDate: expiresOn ?? DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => expiresOn = picked);
                                  }
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: _announcementInputDecoration().copyWith(
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 19,
                              ),
                            ),
                            child: Text(
                              expiresOn == null
                                  ? 'dd-mm-yyyy'
                                  : _formatDate(expiresOn!),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: expiresOn == null
                                    ? const Color(0xFF7A7F88)
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: sending
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: sending ? null : send,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2F80ED),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Send',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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

  String _targetGroupForAudience(String audience) {
    switch (audience) {
      case 'students':
      case 'batch':
      case 'course':
        return 'student';
      case 'mentors':
        return 'mentor';
      default:
        return 'both';
    }
  }

  String _labelForPriority(String priority) {
    switch (priority) {
      case 'important':
        return 'Important';
      case 'urgent':
        return 'Urgent';
      default:
        return 'Normal';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
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

class _AnnouncementLabel extends StatelessWidget {
  const _AnnouncementLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF374151),
      ),
    );
  }
}

InputDecoration _announcementInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2F80ED), width: 1.4),
    ),
  );
}

class _AnnouncementTextField extends StatelessWidget {
  const _AnnouncementTextField({
    required this.controller,
    required this.hintText,
    required this.enabled,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 18),
      decoration: _announcementInputDecoration().copyWith(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: const Color(0xFF7A7F88)),
      ),
    );
  }
}

class _AnnouncementDropdown<T> extends StatelessWidget {
  const _AnnouncementDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnnouncementLabel(label),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          decoration: _announcementInputDecoration(),
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: const Color(0xFF111827),
          ),
          dropdownColor: Colors.white,
        ),
      ],
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

  static const _navItems = [
    LmsNavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Users',
    ),
    LmsNavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Courses',
    ),
    LmsNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    LmsNavItem(
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers_rounded,
      label: 'Batches',
    ),
    LmsNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedLmsNavBar(
      currentIndex: currentIndex,
      items: _navItems,
      onTap: onItemSelected,
      activeColor: const Color(0xFF2563EB),
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
    final now = DateTime.now();
    final visibleNotifications = notifications
        .where((item) {
          final read = item['read'] == true;
          final createdRaw = (item['created_at'] ?? '').toString();
          final createdAt = DateTime.tryParse(createdRaw);
          if (!read) return true;
          if (createdAt == null) return true;
          return now.difference(createdAt).inDays < 7;
        })
        .toList(growable: false);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFF),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF4338CA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF64748B),
                ),
              ],
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
                : visibleNotifications.isEmpty
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
                    itemCount: visibleNotifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = visibleNotifications[index];
                      final sender = (item['sender'] ?? 'System').toString();
                      final title = (item['title'] ?? 'Notification')
                          .toString();
                      final message = (item['message'] ?? '').toString();
                      final senderRole = (item['sender_role'] ?? 'unknown')
                          .toString();
                      final createdAt = (item['created_at'] ?? '')
                          .toString()
                          .trim();

                      final isRead = item['read'] == true;

                      return InkWell(
                        onTap: () async {
                          final id = (item['id'] ?? '').toString();
                          if (id.isEmpty) return;
                          try {
                            await ApiService.instance.markNotificationRead(id);
                          } catch (_) {
                            // Ignore errors; keep UI responsive.
                          }
                          onRefresh();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
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
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
