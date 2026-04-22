import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';

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

  UserRole _role = UserRole.student;
  String _selectedGender = 'Prefer not to say';
  String? _selectedCourse;
  bool _isImporting = false;

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
    await ApiService.instance.createUser(
      name: name,
      email: email,
      password: password,
      role: 'student',
      phone: phone,
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

    try {
      if (_role == UserRole.student) {
        await _createStudentUser(
          name: name,
          email: email,
          password: password,
          phone: phone,
          courseName: _selectedCourse,
        );
      } else {
        await ApiService.instance.createUser(
          name: name,
          email: email,
          password: password,
          role: roleString,
          phone: phone,
        );
      }

      if (!mounted) return;

      await Provider.of<AuthProvider>(context, listen: false).loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User created successfully',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      _formKey.currentState!.reset();
      setState(() {
        _selectedGender = 'Prefer not to say';
        _selectedCourse = null;
      });
    } on DuplicateEmailException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user', style: GoogleFonts.poppins()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importStudentsFromCsv() async {
    if (_isImporting) return;

    final picker = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
      allowMultiple: false,
    );

    if (picker == null || picker.files.isEmpty) {
      return;
    }

    final file = picker.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to read the selected CSV file',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      await _ensureCoursesLoaded();
      final authProvider = context.read<AuthProvider>();
      await authProvider.loadUsers();

      final existingEmails = authProvider.allUsers
          .map((user) => user.email.trim().toLowerCase())
          .where((email) => email.isNotEmpty)
          .toSet();
      final seenEmails = <String>{};

      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(utf8.decode(bytes));

      if (rows.isEmpty) {
        throw ApiException('CSV file is empty');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _showImportSummary({
    required int successCount,
    required int failedCount,
    required List<String> errors,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Import Summary',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryTile(
                    icon: Icons.check_circle_outline,
                    label: 'Successfully added users',
                    value: '$successCount',
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 10),
                  _SummaryTile(
                    icon: Icons.error_outline,
                    label: 'Failed entries',
                    value: '$failedCount',
                    color: const Color(0xFFEF4444),
                  ),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Error report',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: errors.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, errorIndex) => Text(
                          errors[errorIndex],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF4B5563),
                          ),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(color: const Color(0xFF2563EB)),
              ),
            ),
          ],
        );
      },
    );
  }

  String _primaryButtonLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Create Student Account';
      case UserRole.mentor:
        return 'Create Mentor Account';
      case UserRole.admin:
        return 'Create Admin Account';
    }
  }

  String _roleToApiRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'student';
      case UserRole.mentor:
        return 'mentor';
      case UserRole.admin:
        return 'admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F7FA);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(role: _role),
                const SizedBox(height: 24),
                Text(
                  'Select User Role',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the type of account you want to create.\nEach role has specific permissions and access levels.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.4,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),

                // Role cards
                _RoleCard(
                  icon: Icons.school_outlined,
                  title: 'Student Account',
                  description: 'Enroll a new learner',
                  selected: _role == UserRole.student,
                  onTap: () {
                    setState(() {
                      _role = UserRole.student;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.group_outlined,
                  title: 'Mentor Account',
                  description: 'Register a professional guide',
                  selected: _role == UserRole.mentor,
                  onTap: () {
                    setState(() {
                      _role = UserRole.mentor;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Account',
                  description: 'Grant administrative privileges',
                  selected: _role == UserRole.admin,
                  onTap: () {
                    setState(() {
                      _role = UserRole.admin;
                    });
                  },
                ),

                const SizedBox(height: 20),

                const _SecureRegistrationCard(),

                const SizedBox(height: 24),

                _buildFormForRole(),

                if (_role == UserRole.student) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isImporting ? null : _importStudentsFromCsv,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(
                        _isImporting ? 'Importing...' : '➕ Import Students',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: const Color(0xFFF8FBFF),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _createUser,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _primaryButtonLabel(_role),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildFormForRole() {
    switch (_role) {
      case UserRole.student:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledTextField(
              label: 'Full Name',
              hintText: 'e.g. Alex Johnson',
              controller: _nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Email Address',
              hintText: 'alex.j@jenovate.edu',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter email address';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Phone Number',
              hintText: 'e.g. 9876543210',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.trim().length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Secret Password',
              hintText: '••••••••••',
              controller: _passwordController,
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _GenderChips(
                    label: 'Gender',
                    options: _genderOptions,
                    selected: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CourseDropdown(
                    label: 'Assign Course',
                    options: context
                        .watch<CourseProvider>()
                        .courses
                        .map((course) => course.title)
                        .toList(growable: false),
                    value: _selectedCourse,
                    onChanged: (value) {
                      setState(() {
                        _selectedCourse = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      case UserRole.mentor:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledTextField(
              label: 'Full Name',
              hintText: 'e.g. Alex Johnson',
              controller: _nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Email Address',
              hintText: 'alex.j@jenovate.edu',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter email address';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Phone Number',
              hintText: 'e.g. 9876543210',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.trim().length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Secret Password',
              hintText: '••••••••••',
              controller: _passwordController,
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Specialization',
              hintText: 'e.g. UI/UX Design',
              controller: _specializationController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter specialization';
                }
                return null;
              },
            ),
          ],
        );
      case UserRole.admin:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledTextField(
              label: 'Full Name',
              hintText: 'e.g. Alex Johnson',
              controller: _nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Email Address',
              hintText: 'alex.j@jenovate.edu',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter email address';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Phone Number',
              hintText: 'e.g. 9876543210',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.trim().length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Secret Password',
              hintText: '••••••••••',
              controller: _passwordController,
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              label: 'Role Level (optional)',
              hintText: 'e.g. Super Admin',
              controller: _roleLevelController,
            ),
          ],
        );
    }
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New User',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ADMIN CONTROL PANEL',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Step 1 of 2',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2563EB),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? const Color(0xFF2563EB)
        : const Color(0xFFE5E7EB);
    final Color backgroundColor = selected
        ? const Color(0xFFEFF6FF)
        : Colors.white;

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
                color: Colors.white,
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
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This user will receive an automated invitation email to verify their identity.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.4,
                    color: const Color(0xFF6B7280),
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
              fillColor: Colors.white,
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
            color: const Color(0xFF4B5563),
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
                    fillColor: Colors.white,
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
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: const Color(0xFF111827),
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
