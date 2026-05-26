import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';


import '../config/theme.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'package:my_app/utils/ui_utils.dart';
import 'package:my_app/widgets/shop_image_thumb.dart';

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({required this.user, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.role == UserRole.admin
        ? 'Admin'
        : user.role == UserRole.mentor
            ? 'Mentor'
            : 'Student';

    final Color roleBg = user.role == UserRole.admin
      ? const Color(0xFFFFEEF0)
      : user.role == UserRole.mentor
        ? const Color(0xFFF5F0FF)
        : const Color(0xFFEFF6FF);
    final Color roleText = user.role == UserRole.admin
      ? const Color(0xFFDC2626)
      : user.role == UserRole.mentor
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE5EF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // square avatar with gradient
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF111827),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (user.profilePicUrl ?? '').isNotEmpty
                      ? ShopImageThumb(imageUrl: user.profilePicUrl!, size: 56)
                      : (user.profilePic ?? '').isNotEmpty
                          ? ShopImageThumb(imageUrl: user.profilePic!, size: 56)
                          : Center(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(user.name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: roleBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(roleLabel, style: GoogleFonts.poppins(fontSize: 12, color: roleText, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFF8FAFF), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Row(children: [const Icon(Icons.email_outlined, size: 14, color: Color(0xFF6B7280)), const SizedBox(width: 8), Expanded(child: Text(user.email, style: GoogleFonts.poppins(fontSize: 13)))]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFF8FAFF), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Row(children: [const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)), const SizedBox(width: 8), Expanded(child: Text(user.username ?? 'N/A', style: GoogleFonts.poppins(fontSize: 13)))]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFFFEEF0)),
                child: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

  // Create User form state
  final _createFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  UserRole _createRole = UserRole.student;
  String _createGender = 'Prefer not to say';
  String? _createSelectedCourse;
  bool _isImporting = false;
  bool _isCreating = false;
  bool _isEmailSaving = false;
  List<List<dynamic>> _importRows = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUsers();
    _searchController.addListener(_applyFilters);
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      _loadUsers();
    }
  }

  Future<void> _openEditUser(BuildContext ctx, AppUser user) async {
    final nameController = TextEditingController(text: user.name);
    final usernameController = TextEditingController(text: user.username ?? '');
    String roleValue = user.role == UserRole.admin
        ? 'admin'
        : user.role == UserRole.mentor
            ? 'mentor'
            : 'student';
    final courseProvider = Provider.of<CourseProvider>(ctx, listen: false);
    await courseProvider.loadCourses();
    String? selectedCourseId = user.courseIds.isNotEmpty ? user.courseIds.first : null;

    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Text('Edit User'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null),
                    const SizedBox(height: 8),
                    TextFormField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: roleValue,
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('Student')),
                        DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) => setDialogState(() => roleValue = v ?? 'student'),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: selectedCourseId,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('No course')),
                        ...courseProvider.courses.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.title)))
                      ],
                      onChanged: (v) => setDialogState(() => selectedCourseId = v),
                      decoration: const InputDecoration(labelText: 'Assign Course (optional)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          final updated = await ApiService.instance.updateUser(
                            user.id,
                            name: nameController.text.trim(),
                            username: usernameController.text.trim().isEmpty ? null : usernameController.text.trim(),
                            role: roleValue,
                            courseIds: selectedCourseId != null ? [selectedCourseId!] : [],
                            includeCourseIds: true,
                          );
                          await Provider.of<AuthProvider>(ctx, listen: false).loadUsers();
                          Navigator.of(dialogCtx).pop();
                          if (!updated) {
                            showTopNotification(ctx, 'Failed to update user');
                          }
                        } catch (e) {
                          Navigator.of(dialogCtx).pop();
                          showTopNotification(ctx, 'Failed: $e');
                        }
                      },
                child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      await Provider.of<AuthProvider>(context, listen: false).loadUsers();
      _applyFilters();
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Failed to load users');
      }
    }
  }

  Course? _findCourseByName(String courseName) {
    final normalized = courseName.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final course in context.read<CourseProvider>().courses) {
      if (course.title.trim().toLowerCase() == normalized) return course;
    }
    return null;
  }

  Future<AppUser?> _findUserByEmail(String email) async {
    final auth = context.read<AuthProvider>();
    final normalized = email.trim().toLowerCase();
    await auth.loadUsers();
    for (final user in auth.allUsers) {
      if (user.email.trim().toLowerCase() == normalized) return user;
    }
    return null;
  }

  List<List<dynamic>> _simpleCsvParse(String content) {
    final lines = const LineSplitter().convert(content);
    final out = <List<dynamic>>[];
    for (final line in lines) {
      final fields = <String>[];
      final buf = StringBuffer();
      var inQuotes = false;
      for (var i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (ch == ',' && !inQuotes) {
          fields.add(buf.toString());
          buf.clear();
        } else {
          buf.write(ch);
        }
      }
      fields.add(buf.toString());
      out.add(fields.map((s) => s.trim()).toList());
    }
    return out;
  }

  Future<void> _pickCsvAndImport() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() => _isImporting = true);
      final file = result.files.first;
      if (file.bytes == null) {
        showTopNotification(context, 'Unable to read CSV');
        setState(() => _isImporting = false);
        return;
      }
      final content = utf8.decode(file.bytes!);
      final parsed = _simpleCsvParse(content);
      setState(() {
        _importRows = parsed;
        _isImporting = false;
      });
      // preload users
      try {
        await Provider.of<AuthProvider>(context, listen: false).loadUsers();
      } catch (_) {}
      showTopNotification(context, 'CSV loaded — ${_importRows.length} rows');
    } catch (e) {
      showTopNotification(context, 'Failed to load CSV: $e');
      setState(() => _isImporting = false);
    }
  }

  Future<void> _createUserInline() async {
    if (!_createFormKey.currentState!.validate()) return;
    if (_isCreating) return;
    setState(() => _isCreating = true);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final roleStr = _createRole == UserRole.admin ? 'admin' : _createRole == UserRole.mentor ? 'mentor' : 'student';
    try {
      await ApiService.instance.createUser(
        name: name,
        email: email,
        password: password,
        role: roleStr,
        phone: phone,
      );
      await Provider.of<AuthProvider>(context, listen: false).loadUsers();
      // assign course if selected
      if (_createSelectedCourse != null && _createSelectedCourse!.isNotEmpty) {
        final created = await _findUserByEmail(email);
        if (created != null) {
          final course = _findCourseByName(_createSelectedCourse!);
          if (course != null) {
            await ApiService.instance.assignCourseToUser(created.id, course.id);
            await Provider.of<AuthProvider>(context, listen: false).loadUsers();
          }
        }
      }
      showTopNotification(context, 'User created');
    } catch (e) {
      showTopNotification(context, 'Create failed: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _applyFilters() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = auth.allUsers.where((u) {
        if (_filterRole != null && u.role != _filterRole) return false;
        if (query.isEmpty) return true;
        final hay = '${u.name} ${u.email} ${u.username ?? ''}'.toLowerCase();
        return hay.contains(query);
      }).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emailConfigFormKey = GlobalKey<FormState>();
    void saveEmailConfig() {}
    final auth = Provider.of<AuthProvider>(context);
    final hasUserFilter = _filterRole != null || _searchController.text.trim().isNotEmpty;
    final displayedUsers = hasUserFilter ? _filteredUsers : auth.allUsers;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.manage_accounts_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Directory',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${auth.allUsers.length} accounts in the LMS',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              indicator: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Create User'),
                Tab(text: 'Manage Users'),
                Tab(text: 'Email Config'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateUserTab(context),
                // Manage Users -> search + list
                RefreshIndicator(
                  onRefresh: () async {
                    await Provider.of<AuthProvider>(context, listen: false).loadUsers();
                    _applyFilters();
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search users by name, email or username',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFF),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ChoiceChip(label: const Text('All'), selected: _filterRole == null, onSelected: (_) => setState(() { _filterRole = null; _applyFilters(); })),
                                const SizedBox(width: 8),
                                ChoiceChip(label: const Text('Students'), selected: _filterRole == UserRole.student, onSelected: (_) => setState(() { _filterRole = UserRole.student; _applyFilters(); })),
                                const SizedBox(width: 8),
                                ChoiceChip(label: const Text('Mentors'), selected: _filterRole == UserRole.mentor, onSelected: (_) => setState(() { _filterRole = UserRole.mentor; _applyFilters(); })),
                                const SizedBox(width: 8),
                                ChoiceChip(label: const Text('Admins'), selected: _filterRole == UserRole.admin, onSelected: (_) => setState(() { _filterRole = UserRole.admin; _applyFilters(); })),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: displayedUsers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final u = displayedUsers[i];
                            return _UserCard(
                              user: u,
                              onEdit: () => _openEditUser(context, u),
                              onDelete: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (dctx) => AlertDialog(
                                    title: const Text('Delete user?'),
                                    content: Text('Are you sure you want to delete ${u.name}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  try {
                                    await ApiService.instance.deleteUser(u.id);
                                    await Provider.of<AuthProvider>(context, listen: false).loadUsers();
                                    _applyFilters();
                                    showTopNotification(context, 'User deleted');
                                  } catch (e) {
                                    showTopNotification(context, 'Failed to delete user');
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Email Config -> original SMTP form
                SingleChildScrollView(
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
                          key: emailConfigFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SMTP Settings', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 4),
                              Text('Configure the email account used to send automated messages.', style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150))),
                              const SizedBox(height: 24),
                              _buildLabel('Sender Email (Gmail)'),
                              const SizedBox(height: 8),
                              TextFormField(controller: _emailController, decoration: _inputDecoration('e.g. admin@gmail.com', Icons.email_outlined), style: GoogleFonts.poppins(fontSize: 14), validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
                              const SizedBox(height: 20),
                              _buildLabel('Gmail App Password'),
                              const SizedBox(height: 8),
                              TextFormField(controller: _passwordController, obscureText: true, decoration: _inputDecoration('16-character app password', Icons.lock_outline), style: GoogleFonts.poppins(fontSize: 14), validator: (v) => (v == null || v.isEmpty) ? 'Enter app password' : null),
                              const SizedBox(height: 32),
                              SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _isEmailSaving ? null : saveEmailConfig, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _isEmailSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Save Configuration', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSecurityNote(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateUserTab(BuildContext context) {
    final courses = context.watch<CourseProvider>().courses;
    final roleTitle = _createRole == UserRole.student
        ? 'Student Account'
        : _createRole == UserRole.mentor
            ? 'Mentor Account'
            : 'Admin Account';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New User',
                        style: GoogleFonts.poppins(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'ADMIN CONTROL PANEL',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'Step 1 of 2',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 250.ms).slideY(begin: .08, end: 0),
            const SizedBox(height: 24),
            Text(
              'Select User Role',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the type of account you want to create.\nEach role has specific permissions and access levels.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.35,
                color: const Color(0xFF7B8190),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _RoleOptionCard(
              title: 'Student Account',
              subtitle: 'Enroll a new learner',
              icon: Icons.school_outlined,
              selected: _createRole == UserRole.student,
              onTap: () => setState(() => _createRole = UserRole.student),
            ).animate().fadeIn(delay: 50.ms).slideX(begin: -.05, end: 0),
            const SizedBox(height: 12),
            _RoleOptionCard(
              title: 'Mentor Account',
              subtitle: 'Register a professional guide',
              icon: Icons.groups_2_outlined,
              selected: _createRole == UserRole.mentor,
              onTap: () => setState(() => _createRole = UserRole.mentor),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -.05, end: 0),
            const SizedBox(height: 12),
            _RoleOptionCard(
              title: 'Admin Account',
              subtitle: 'Grant administrative privileges',
              icon: Icons.admin_panel_settings_outlined,
              selected: _createRole == UserRole.admin,
              onTap: () => setState(() => _createRole = UserRole.admin),
            ).animate().fadeIn(delay: 150.ms).slideX(begin: -.05, end: 0),
            const SizedBox(height: 18),
            _InfoPanel(
              icon: Icons.verified_user_outlined,
              title: 'Secure Registration',
              subtitle: 'This user will receive an automated invitation email to verify their identity.',
            ).animate().fadeIn(delay: 180.ms).slideY(begin: .08, end: 0),
            const SizedBox(height: 24),
            _CreateLabel('Full Name'),
            const SizedBox(height: 8),
            _SoftTextField(
              controller: _nameController,
              hintText: 'e.g. Alex Johnson',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 16),
            _CreateLabel('Email Address'),
            const SizedBox(height: 8),
            _SoftTextField(
              controller: _emailController,
              hintText: 'alex.j@jenovate.edu',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
            ),
            const SizedBox(height: 16),
            _CreateLabel('Phone Number'),
            const SizedBox(height: 8),
            _SoftTextField(
              controller: _phoneController,
              hintText: 'e.g. 9876543210',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _CreateLabel('Secret Password'),
            const SizedBox(height: 8),
            _SoftTextField(
              controller: _passwordController,
              hintText: '**********',
              obscureText: true,
              validator: (v) {
                if ((_createRole == UserRole.admin || _createRole == UserRole.student) &&
                    (v == null || v.trim().length < 6)) {
                  return 'Enter a password (min 6 chars)';
                }
                return null;
              },
            ),
            if (_createRole == UserRole.mentor) ...[
              const SizedBox(height: 16),
              _CreateLabel('Specialization'),
              const SizedBox(height: 8),
              _SoftTextField(
                controller: _specializationController,
                hintText: 'e.g. Flutter, Data Science',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter specialization' : null,
              ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_createRole == UserRole.student)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CreateLabel('Gender'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Male', 'Female', 'Prefer not to say'].map((g) {
                            final selected = g == _createGender;
                            return ChoiceChip(
                              label: Text(g),
                              selected: selected,
                              onSelected: (_) => setState(() => _createGender = g),
                              selectedColor: const Color(0xFF0F75FF),
                              backgroundColor: Colors.white,
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : const Color(0xFF6B7280),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                                side: BorderSide(
                                  color: selected ? const Color(0xFF0F75FF) : const Color(0xFFE5E7EB),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (_createRole == UserRole.student) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CreateLabel('Assign Course'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _createSelectedCourse,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Assign')),
                          ...courses.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.title,
                              child: Text(c.title, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _createSelectedCourse = v),
                        decoration: _softInputDecoration(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _isImporting ? null : _pickCsvAndImport,
                icon: const Icon(Icons.upload_rounded),
                label: Text(
                  'Import Students',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F75FF),
                  side: const BorderSide(color: Color(0xFFBDE3FF), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _InfoPanel(
              icon: Icons.email_outlined,
              title: 'Email Config (Optional)',
              subtitle: 'Leave blank to use global SMTP configuration',
              trailing: Icons.keyboard_arrow_down_rounded,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: _isCreating ? null : _createUserInline,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F75FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 8,
                  shadowColor: const Color(0xFF0F75FF).withOpacity(.28),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Create $roleTitle',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
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

InputDecoration _softInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
    ),
  );
}

class _CreateLabel extends StatelessWidget {
  const _CreateLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF4B5563),
      ),
    );
  }
}

class _SoftTextField extends StatelessWidget {
  const _SoftTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _softInputDecoration().copyWith(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFBDC4D0),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF4FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF0F75FF) : const Color(0xFFE5E7EB),
          width: selected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFF0F75FF).withOpacity(.10)
                : const Color(0xFF111827).withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0F75FF), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8A91A0),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? const CircleAvatar(
                          key: ValueKey('selected'),
                          radius: 12,
                          backgroundColor: Color(0xFF0F75FF),
                          child: Icon(Icons.check_rounded, size: 15, color: Colors.white),
                        )
                      : Container(
                          key: const ValueKey('empty'),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0F75FF), size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8A91A0),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, color: const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}
