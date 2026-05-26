import 'dart:convert';

import 'package:csv/csv.dart' as csv;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'package:my_app/utils/ui_utils.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  static const routeName = '/admin/add-user';

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _roleLevelController = TextEditingController();
  final _senderEmailController = TextEditingController();
  final _senderPasswordController = TextEditingController();

  UserRole _role = UserRole.student;
  String _selectedGender = 'Prefer not to say';
  String? _selectedCourse;
  bool _isImporting = false;
  List<List<dynamic>> rows = const [];
  final Set<String> seenEmails = <String>{};
  final Set<String> existingEmails = <String>{};

  final List<String> _genderOptions = const [
    'Male',
    'Female',
    'Prefer not to say',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CourseProvider>().loadCourses();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _roleLevelController.dispose();
    _senderEmailController.dispose();
    _senderPasswordController.dispose();
    super.dispose();
  }

  Course? _findCourseByName(String courseName) {
    final normalized = courseName.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final course in context.read<CourseProvider>().courses) {
      if (course.title.trim().toLowerCase() == normalized) {
        return course;
      }
    }
    return null;
  }

  Future<void> _ensureCoursesLoaded() async {
    final courseProvider = context.read<CourseProvider>();
    if (courseProvider.courses.isEmpty) {
      await courseProvider.loadCourses();
    }
  }

  Future<AppUser?> _findUserByEmail(String email) async {
    final auth = context.read<AuthProvider>();
    final normalized = email.trim().toLowerCase();
    await auth.loadUsers();
    for (final user in auth.allUsers) {
      if (user.email.trim().toLowerCase() == normalized) {
        return user;
      }
    }
    return null;
  }

  Future<void> _assignCourseIfNeeded({
    required String email,
    String? courseName,
  }) async {
    final normalizedCourse = courseName?.trim() ?? '';
    if (normalizedCourse.isEmpty) return;

    await _ensureCoursesLoaded();
    final course = _findCourseByName(normalizedCourse);
    if (course == null) {
      throw ApiException('Course "$normalizedCourse" not found');
    }

    final createdUser = await _findUserByEmail(email);
    if (createdUser == null) {
      throw ApiException('Created user could not be found for course assignment');
    }

    await ApiService.instance.assignCourseToUser(createdUser.id, course.id);
  }

  Future<void> _createStudentUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? courseName,
  }) async {
    // Resolve course name to title for email
    final List<String> courseNamesForEmail = [];
    if (courseName != null && courseName.isNotEmpty) {
      courseNamesForEmail.add(courseName);
    }

    final senderEmail = _senderEmailController.text.trim();
    final senderPassword = _senderPasswordController.text.trim();

    await ApiService.instance.createUser(
      name: name,
      email: email,
      password: password,
      role: 'student',
      phone: phone,
      senderEmail: senderEmail.isNotEmpty ? senderEmail : null,
      senderPassword: senderPassword.isNotEmpty ? senderPassword : null,
      courseNames: courseNamesForEmail,
    );
    await _assignCourseIfNeeded(email: email, courseName: courseName);
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final roleString = _roleToApiRole(_role);
    final senderEmail = _senderEmailController.text.trim();
    final senderPassword = _senderPasswordController.text.trim();

    try {
      Map<String, dynamic> result;
      if (_role == UserRole.student) {
        await _createStudentUser(
          name: name,
          email: email,
          password: password,
          phone: phone,
          courseName: _selectedCourse,
        );
        result = {};
      } else {
        result = await ApiService.instance.createUser(
          name: name,
          email: email,
          password: password,
          role: roleString,
          phone: phone,
          senderEmail: senderEmail.isNotEmpty ? senderEmail : null,
          senderPassword: senderPassword.isNotEmpty ? senderPassword : null,
        );
      }

      if (!mounted) return;

      final emailSent = result['email_sent'] == true;
      final emailWarning = result['email_warning'];
      final msg = emailSent
          ? 'User created ✅  Welcome email sent!'
          : emailWarning != null
              ? 'User created ⚠️  $emailWarning'
              : 'User created successfully';

      await Provider.of<AuthProvider>(context, listen: false).loadUsers();
      showTopNotification(context, msg);

      // If not importing via CSV, stop here.
      if (!_isImporting) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final header = rows.first
          .map((cell) => cell.toString().trim().toLowerCase())
          .toList(growable: false);
      final headerMap = <String, int>{
        for (var i = 0; i < header.length; i++)
          if (header[i].isNotEmpty) header[i]: i,
      };
      const requiredHeaders = [
        'name',
        'email',
        'phone',
        'gender',
        'password',
        'course',
      ];
      final hasHeader = requiredHeaders.every(headerMap.containsKey);

      final dataRows = hasHeader ? rows.skip(1).toList(growable: false) : rows;
      final errors = <String>[];
      var successCount = 0;

      String readCell(List<dynamic> row, String key, int fallbackIndex) {
        if (hasHeader) {
          final index = headerMap[key];
          if (index == null || index >= row.length) return '';
          return row[index].toString().trim();
        }
        if (fallbackIndex >= row.length) return '';
        return row[fallbackIndex].toString().trim();
      }

      for (var index = 0; index < dataRows.length; index++) {
        final rowNumber = hasHeader ? index + 2 : index + 1;
        final row = dataRows[index];
        final name = readCell(row, 'name', 0);
        final email = readCell(row, 'email', 1).toLowerCase();
        final phone = readCell(row, 'phone', 2);
        final gender = readCell(row, 'gender', 3);
        final password = readCell(row, 'password', 4);
        final courseName = readCell(row, 'course', 5);

        final validationErrors = <String>[];
        if (name.isEmpty) validationErrors.add('name is required');
        if (email.isEmpty) {
          validationErrors.add('email is required');
        } else if (!email.contains('@')) {
          validationErrors.add('email is invalid');
        }
        if (phone.isEmpty) validationErrors.add('phone is required');
        if (gender.isEmpty) validationErrors.add('gender is required');
        if (password.isEmpty) validationErrors.add('password is required');
        if (courseName.isEmpty) validationErrors.add('course is required');

        if (validationErrors.isNotEmpty) {
          errors.add('Row $rowNumber: ${validationErrors.join(', ')}');
          continue;
        }

        if (seenEmails.contains(email) || existingEmails.contains(email)) {
          errors.add('Row $rowNumber: duplicate email "$email"');
          continue;
        }

        final course = _findCourseByName(courseName);
        if (course == null) {
          errors.add('Row $rowNumber: course "$courseName" not found');
          continue;
        }

        try {
          await _createStudentUser(
            name: name,
            email: email,
            password: password,
            phone: phone,
            courseName: course.title,
          );
          seenEmails.add(email);
          existingEmails.add(email);
          successCount += 1;
        } on DuplicateEmailException {
          errors.add('Row $rowNumber: duplicate email "$email"');
        } on ApiException catch (e) {
          errors.add('Row $rowNumber: ${e.message}');
        } catch (e) {
          errors.add('Row $rowNumber: $e');
        }
      }

      await Provider.of<AuthProvider>(context, listen: false).loadUsers();

      if (!mounted) return;
      _showImportSummary(
        successCount: successCount,
        failedCount: errors.length,
        errors: errors,
      );
    } on ApiException catch (e) {
      if (mounted) {
        showTopNotification(context, e.message);
      }
    }
  }

  Future<void> _pickCsvAndImport() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        _isImporting = true;
      });

      final file = result.files.first;
      if (file.bytes == null) {
        showTopNotification(context, 'Unable to read CSV file content');
        setState(() => _isImporting = false);
        return;
      }

      final content = utf8.decode(file.bytes!);
      final parsed = _simpleCsvParse(content);

      setState(() {
        rows = parsed;
        seenEmails.clear();
        existingEmails.clear();
        _isImporting = false;
      });

      // preload existing users to prevent duplicates
      try {
        await Provider.of<AuthProvider>(context, listen: false).loadUsers();
        final auth = Provider.of<AuthProvider>(context, listen: false);
        for (final u in auth.allUsers) {
          existingEmails.add(u.email.trim().toLowerCase());
        }
      } catch (_) {}

      showTopNotification(context, 'CSV loaded — ${rows.length} rows');
    } catch (e) {
      showTopNotification(context, 'Failed to load CSV: $e');
      setState(() => _isImporting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context);
    final courses = courseProvider.courses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select User Role', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RoleOption(
                    title: 'Student Account',
                    description: 'Enroll a new learner',
                    icon: Icons.school_outlined,
                    selected: _role == UserRole.student,
                    onTap: () => setState(() => _role = UserRole.student),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleOption(
                    title: 'Mentor Account',
                    description: 'Register a professional guide',
                    icon: Icons.person_outline,
                    selected: _role == UserRole.mentor,
                    onTap: () => setState(() => _role = UserRole.mentor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _selectedCourse,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No course')),
                      ...courses.map((c) => DropdownMenuItem<String?>(value: c.title, child: Text(c.title)))
                    ],
                    onChanged: (v) => setState(() => _selectedCourse = v),
                    decoration: const InputDecoration(labelText: 'Assign Course (optional)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(onPressed: _isImporting ? null : _pickCsvAndImport, icon: const Icon(Icons.upload_file), label: const Text('Import Students')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createUser,
                          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Student Account'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleToApiRole(UserRole role) {
    switch (role) {
      case UserRole.admin: return 'admin';
      case UserRole.mentor: return 'mentor';
      case UserRole.student: return 'student';
    }
  }

  void _showImportSummary({required int successCount, required int failedCount, required List<String> errors}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Summary'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Success: $successCount'),
                Text('Failed: $failedCount'),
                const SizedBox(height: 8),
                if (errors.isNotEmpty) ...[
                  const Text('Errors:'),
                  const SizedBox(height: 6),
                  for (final e in errors) Text('- $e', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected ? const Color(0xFF2563EB) : (isDark ? Colors.white.withAlpha(20) : const Color(0xFFE5E7EB));
    final Color backgroundColor = selected
        ? (isDark ? const Color(0xFF1E3A8A).withAlpha(80) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: selected ? const Color(0xFF2563EB) : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecureRegistrationCard extends StatelessWidget {
  const _SecureRegistrationCard();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withAlpha(20) : const Color(0xFFE5E7EB)),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Registration',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This user will receive an automated invitation email to verify their identity.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  final String label;
  final String hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E293B) 
                : const Color(0xFFF8FAFF),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

class _GenderChips extends StatelessWidget {
  const _GenderChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final bool isSelected = option == selected;
            return ChoiceChip(
              label: Text(
                option,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
              selected: isSelected,
              onSelected: (value) {
                if (value) onChanged(option);
              },
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CourseDropdown extends StatelessWidget {
  const _CourseDropdown({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: options.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Text(
                    'No courses available',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                )
              : DropdownButtonFormField<String>(
                  initialValue: value != null && options.contains(value)
                      ? value
                      : null,
                  items: options
                      .map(
                        (courseName) => DropdownMenuItem<String>(
                          value: courseName,
                          child: Text(
                            courseName,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Assign Course',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF9CA3AF),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  icon: const Icon(
                    Icons.expand_more_rounded,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
