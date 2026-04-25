import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'add_user_screen.dart';

class ManageUserScreen extends StatefulWidget {
  const ManageUserScreen({super.key});

  static const routeName = '/admin/manage-user';

  @override
  State<ManageUserScreen> createState() => _ManageUserScreenState();
}

class _ManageUserScreenState extends State<ManageUserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  UserRole? _filterRole;
  List<AppUser> _filteredUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).loadUsers();
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users', style: GoogleFonts.poppins()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    var users = auth.allUsers; // Get all users from AuthProvider

    // Apply role filter
    if (_filterRole != null) {
      users = users.where((u) => u.role == _filterRole).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      users = users.where((u) {
        return u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            (u.username?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    setState(() {
      _filteredUsers = users;
    });
  }

  void _showEditUserDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(user: user, onSave: _loadUsers),
    );
  }

  void _showDeleteConfirmation(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete User',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF3B82F6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(user);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(AppUser user) async {
    try {
      final success = await ApiService.instance.deleteUser(user.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.name} deleted successfully',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        await _loadUsers();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
        );
      }
    }
  }

  void _showAssignCourseDialog(AppUser user) {
    if (user.role != UserRole.student && user.role != UserRole.mentor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Course assignment is available only for students and mentors.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) =>
          _AssignCourseDialog(user: user, onAssign: _loadUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F7FA);
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.currentRole == UserRole.admin;

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 52,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Admin access required',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only admins can assign courses and manage users.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 4,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Users',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Admin Control Panel',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF1D4ED8),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFDBEAFE),
                  ),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(6),
                  tabs: [
                    Tab(
                      child: Text(
                        'Create User',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Tab(
                      child: Text(
                        'Manage Users',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Tab(
                      child: Text(
                        'Email Config',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Create User Tab
                  const AddUserScreen(),
                  // Manage Users Tab
                  _buildManageUsersTab(),
                  // Email Config Tab
                  const _EmailConfigTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageUsersTab() {
    const backgroundColor = Color(0xFFF5F7FA);

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or username...',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('All', style: GoogleFonts.poppins()),
                          selected: _filterRole == null,
                          selectedColor: const Color(0xFFDBEAFE),
                          onSelected: (selected) {
                            setState(() {
                              _filterRole = null;
                            });
                            _applyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Students', style: GoogleFonts.poppins()),
                          selected: _filterRole == UserRole.student,
                          selectedColor: const Color(0xFFDBEAFE),
                          onSelected: (selected) {
                            setState(() {
                              _filterRole = selected ? UserRole.student : null;
                            });
                            _applyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Mentors', style: GoogleFonts.poppins()),
                          selected: _filterRole == UserRole.mentor,
                          selectedColor: const Color(0xFFDBEAFE),
                          onSelected: (selected) {
                            setState(() {
                              _filterRole = selected ? UserRole.mentor : null;
                            });
                            _applyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Admins', style: GoogleFonts.poppins()),
                          selected: _filterRole == UserRole.admin,
                          selectedColor: const Color(0xFFDBEAFE),
                          onSelected: (selected) {
                            setState(() {
                              _filterRole = selected ? UserRole.admin : null;
                            });
                            _applyFilters();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) {
                      return Shimmer.fromColors(
                        baseColor: const Color(0xFFF1F5F9),
                        highlightColor: Colors.white,
                        child: Container(
                          height: 140,
                          decoration: LmsAdminTheme.adminCardDecoration(context),
                        ),
                      );
                    },
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Color(0xFFD1D5DB),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _UserCard(
                          user: user,
                          onEdit: () => _showEditUserDialog(user),
                          onDelete: () => _showDeleteConfirmation(user),
                          onAssignCourse: () => _showAssignCourseDialog(user),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignCourse;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignCourse,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve course IDs to names via CourseProvider (already loaded).
    final allCourses = context.watch<CourseProvider>().courses;
    final List<String> courseNames = user.courseIds
        .map((id) {
          try {
            return allCourses.firstWhere((c) => c.id == id).title;
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              _getRoleColor(user.role),
                              _getRoleColor(user.role).withAlpha(190),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getRoleColor(user.role).withAlpha(64),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getRoleLabel(user.role),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _getRoleColor(user.role),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getRoleColor(user.role).withAlpha(50), width: 0.5),
                  ),
                  child: Text(
                    _getRoleLabel(user.role),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Theme.of(context).dividerColor.withAlpha(50)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _infoPanel(
                    context: context,
                    label: 'Email',
                    value: user.email,
                    icon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _infoPanel(
                    context: context,
                    label: 'Username',
                    value: user.username ?? 'N/A',
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
            // Course assignments (students & mentors only)
            if (courseNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 12, color: Color(0xFF0284C7)),
                        const SizedBox(width: 4),
                        Text(
                          'Assigned Courses',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: courseNames.map((name) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0369A1),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: const Color(0xFF3B82F6),
                    filled: true,
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 8),

                if (user.role == UserRole.student || user.role == UserRole.mentor) ...[
                  Expanded(
                    child: _CardActionButton(
                      icon: Icons.assignment_outlined,
                      label: 'Edit Assignment',
                      color: const Color(0xFF10B981),
                      filled: true,
                      onTap: onAssignCourse,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                _CardActionButton(
                  icon: Icons.delete_outline,
                  label: '',
                  color: const Color(0xFFEF4444),
                  compact: true,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.mentor:
        return 'Mentor';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const Color(0xFF3B82F6);
      case UserRole.mentor:
        return const Color(0xFF10B981);
      case UserRole.admin:
        return const Color(0xFFDC2626);
    }
  }

  Widget _infoPanel({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155).withAlpha(100) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withAlpha(20) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: onSurface.withAlpha(140)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: onSurface.withAlpha(140),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: onSurface,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final AppUser user;
  final VoidCallback onSave;

  const _EditUserDialog({required this.user, required this.onSave});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _expertiseController;
  late UserRole _selectedRole;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _usernameController = TextEditingController(
      text: widget.user.username ?? '',
    );
    _expertiseController = TextEditingController(
      text: widget.user.expertise.join(', '),
    );
    _selectedRole = widget.user.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _expertiseController.dispose();
    super.dispose();
  }

  List<String> _parseExpertise(String input) {
    final parts = input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final key = p.toLowerCase();
      if (seen.add(key)) out.add(p);
    }
    return out;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final expertise = _selectedRole == UserRole.mentor
          ? _parseExpertise(_expertiseController.text)
          : null;

      final success = await ApiService.instance.updateUser(
        widget.user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        role: _roleToString(_selectedRole),
        expertise: expertise,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User updated successfully',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        Navigator.pop(context);
        widget.onSave();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit User',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (editable)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Role Selection
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: UserRole.student,
                    child: Text('Student', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: UserRole.mentor,
                    child: Text('Mentor', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: UserRole.admin,
                    child: Text('Admin', style: GoogleFonts.poppins()),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),

              if (_selectedRole == UserRole.mentor) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expertiseController,
                  decoration: InputDecoration(
                    labelText: 'Expertise (comma-separated)',
                    hintText: 'e.g. Flutter, UI/UX, AI',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Save',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}

class _AssignCourseDialog extends StatefulWidget {
  final AppUser user;
  final VoidCallback onAssign;

  const _AssignCourseDialog({required this.user, required this.onAssign});

  @override
  State<_AssignCourseDialog> createState() => _AssignCourseDialogState();
}

class _AssignCourseDialogState extends State<_AssignCourseDialog> {
  final Set<String> _selectedCourseIds = <String>{};
  bool _isLoading = false;
  bool _isLoadingCourses = false;
  List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    _selectedCourseIds.addAll(widget.user.courseIds);
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
    });

    try {
      // First load courses from API
      await Provider.of<CourseProvider>(context, listen: false).loadCourses();

      // Then get the loaded courses
      final courses = Provider.of<CourseProvider>(
        context,
        listen: false,
      ).courses;

      final filtered = courses.where((c) {
        if (c.createdByAdmin) return true;
        final normalizedStatus = c.status.trim().toLowerCase();
        return normalizedStatus == 'published' || normalizedStatus == 'publish';
      }).toList();

      setState(() {
        _courses = filtered;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load courses: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
      }
    }
  }

  Future<void> _assignCourse() async {
    final original = widget.user.courseIds.toSet();
    final selected = _selectedCourseIds.toSet();
    if (selected.length == original.length && selected.containsAll(original)) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No assignment changes detected',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ApiService.instance.updateUser(
        widget.user.id,
        role: widget.user.role == UserRole.mentor ? 'mentor' : 'student',
        expertise: widget.user.role == UserRole.mentor ? widget.user.expertise : null,
        courseIds: _selectedCourseIds.toList(growable: false),
        includeCourseIds: true,
      );

      if (success && context.mounted) {
        await context.read<AuthProvider>().loadUsers();
        await context.read<AuthProvider>().refreshCurrentUser();
        await context.read<CourseProvider>().loadCourses();
        if (kDebugMode) {
          print('User ${widget.user.id} assigned courses: ${_selectedCourseIds.toList(growable: false)}');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assignment updated successfully',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        Navigator.pop(context);
        widget.onAssign();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.user.role == UserRole.mentor ? 'Mentor' : 'Student';
    final selectedCourses = _courses
        .where((c) => _selectedCourseIds.contains(c.id))
        .toList(growable: false);

    return AlertDialog(
      title: Text(
        'Edit Assignment • $roleLabel',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: _isLoadingCourses
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
          ? Center(
              child: Text('No courses available', style: GoogleFonts.poppins()),
            )
          : SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select courses for ${widget.user.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _courses.length,
                        itemBuilder: (context, index) {
                          final course = _courses[index];
                          final selected = _selectedCourseIds.contains(course.id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            title: Text(
                              course.title,
                              style: GoogleFonts.poppins(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              course.category.isEmpty ? 'General' : course.category,
                              style: GoogleFonts.poppins(fontSize: 10),
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedCourseIds.add(course.id);
                                } else {
                                  _selectedCourseIds.remove(course.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Selected: ${selectedCourses.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignCourse,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Save Assignment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(colors: [color.withOpacity(0.92), color])
              : null,
          color: filled ? null : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: compact
              ? Border.all(color: const Color(0xFFFECACA), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : color),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmailConfigTab extends StatefulWidget {
  const _EmailConfigTab();

  @override
  State<_EmailConfigTab> createState() => _EmailConfigTabState();
}

class _EmailConfigTabState extends State<_EmailConfigTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final config = await ApiService.instance.getEmailConfig();
      if (config['email'] != null) {
        _emailController.text = config['email'] as String;
        _passwordController.text = '••••••••••••••••';
        if (config['updatedAt'] != null) {
          final dt = DateTime.parse(config['updatedAt'] as String).toLocal();
          _lastUpdated = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      debugPrint('Error fetching email config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final success = await ApiService.instance.updateEmailConfig(
        email: _emailController.text.trim(),
        appPassword: _passwordController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configuration saved successfully!', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
        _fetchConfig();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: LmsAdminTheme.adminCardDecoration(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMTP Settings',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure the email account used to send automated messages.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Sender Email (Gmail)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration('e.g. admin@gmail.com', Icons.email_outlined),
                    style: GoogleFonts.poppins(fontSize: 14),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Gmail App Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecoration('16-character app password', Icons.lock_outline),
                    style: GoogleFonts.poppins(fontSize: 14),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter app password' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Save Configuration',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                  if (_lastUpdated != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Last updated: $_lastUpdated',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF2563EB)),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withAlpha(64),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Sender System',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  'Setup a global email for onboarding.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withAlpha(200)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_rounded, size: 18, color: Color(0xFFEA580C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gmail Security Requirement',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF9A3412)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use a 16-character App Password generated from your Google Account settings. Do not use your regular account password.',
                  style: GoogleFonts.poppins(fontSize: 11, height: 1.5, color: const Color(0xFFC2410C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
