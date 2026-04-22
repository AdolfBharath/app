import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  static const routeName = '/admin/add-course';

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _thumbnailController = TextEditingController();

  static const List<String> _categoryOptions = <String>[
    'Development',
    'Design',
    'Business',
    'Marketing',
    'IT & Software',
    'Personal Development',
  ];

  String _selectedCategory = 'Development';

  String? _selectedMentorId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMentorId == null || _selectedMentorId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a mentor')));
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _selectedCategory.trim();
    final duration = _durationController.text.trim();
    final thumbnailUrl = _thumbnailController.text.trim();

    try {
      final success = await ApiService.instance.createCourse(
        title,
        description,
        category: category,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        mentorId: _selectedMentorId,
      );

      if (!mounted) return;

      if (success) {
        await Provider.of<CourseProvider>(context, listen: false).loadCourses();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Course created successfully',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save course', style: GoogleFonts.poppins()),
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

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F7FA);
    final mentors = Provider.of<AuthProvider>(context).mentors;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Course',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Curriculum Builder',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Design high-impact courses by detailing modules, mentors, and learning paths.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Course Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ACADEMIC FRAMEWORK',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.1,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'COURSE TITLE *',
                        child: TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration(
                            'e.g. Fullstack Development 2024',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a course title';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LabeledField(
                        label: 'ASSIGN LEAD MENTOR *',
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMentorId,
                          decoration: _inputDecoration(
                            'Browse faculty members...',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Select a mentor'),
                            ),
                            ...mentors.map(
                              (m) => DropdownMenuItem<String>(
                                value: m.id,
                                child: Text(
                                  m.name,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedMentorId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a mentor';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: 'CATEGORY',
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                decoration: _inputDecoration('Development'),
                                items: _categoryOptions
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c,
                                        child: Text(
                                          c,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledField(
                              label: 'DURATION',
                              child: TextFormField(
                                controller: _durationController,
                                decoration: _inputDecoration('8 Weeks')
                                    .copyWith(
                                      suffixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Text(
                                          'EST.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ),
                                      suffixIconConstraints:
                                          const BoxConstraints(minWidth: 0),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LabeledField(
                        label: 'DETAILED DESCRIPTION',
                        child: TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: _inputDecoration(
                            'Outline the course objectives, syllabus breakdown, and expected student outcomes...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LabeledField(
                        label: 'THUMBNAIL IMAGE URL',
                        child: TextFormField(
                          controller: _thumbnailController,
                          decoration: _inputDecoration(
                            'https://images.unsplash.com/...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                color: Color(0xFF9CA3AF),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'IMAGE PREVIEW',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'All submitted course materials are subject to the Academy\'s Quality Assurance and Faculty Review boards.',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Edit Course',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
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
                            'Create Course',
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF9CA3AF),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
