import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import '../../models/course.dart';
import '../../services/api_service.dart' as admin_api;

/// Edit dialog for updating course details
class CourseEditDialog extends StatefulWidget {
  const CourseEditDialog({super.key, required this.course});

  final Course course;

  @override
  State<CourseEditDialog> createState() => _CourseEditDialogState();
}

class _CourseEditDialogState extends State<CourseEditDialog> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructorController;
  late final TextEditingController _thumbnailController;
  late final TextEditingController _categoryController;
  late final TextEditingController _durationController;
  late final TextEditingController _ratingController;
  late final TextEditingController _priceController;
  String _difficulty = 'intermediate';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _titleController = TextEditingController(text: widget.course.title);
    _descriptionController = TextEditingController(
      text: widget.course.description,
    );
    _instructorController = TextEditingController(
      text: widget.course.instructorName,
    );
    _thumbnailController = TextEditingController(
      text: widget.course.thumbnailUrl,
    );
    _categoryController = TextEditingController(text: 'Development');
    _durationController = TextEditingController(text: '');
    _ratingController = TextEditingController(
      text: widget.course.rating.toStringAsFixed(1),
    );
    _priceController = TextEditingController(
      text: widget.course.price.toStringAsFixed(2),
    );
    _difficulty = widget.course.difficulty.name;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructorController.dispose();
    _thumbnailController.dispose();
    _categoryController.dispose();
    _durationController.dispose();
    _ratingController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final ok = await admin_api.ApiService.instance.updateCourseDetails(
        widget.course.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        duration: _durationController.text.trim(),
        instructorName: _instructorController.text.trim(),
        thumbnailUrl: _thumbnailController.text.trim(),
        difficulty: _difficulty,
        rating:
            double.tryParse(_ratingController.text.trim()) ??
            widget.course.rating,
        price:
            double.tryParse(_priceController.text.trim()) ??
            widget.course.price,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Course updated' : 'Update failed',
            style: GoogleFonts.poppins(),
          ),
        ),
      );

      if (ok) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final double dialogWidth = math.min(520, screen.width - 24);
    final bool isCompact = dialogWidth < 420;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screen.height * 0.90),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Course',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2563EB).withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFormField(_titleController, 'Title'),
                      const SizedBox(height: 20),
                      _buildFormField(
                        _descriptionController,
                        'Description',
                        maxLines: 5,
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(_instructorController, 'Instructor'),
                      const SizedBox(height: 20),
                      _buildFormField(_thumbnailController, 'Thumbnail URL'),
                      const SizedBox(height: 20),
                      if (isCompact) ...[
                        _buildFormField(_categoryController, 'Category'),
                        const SizedBox(height: 20),
                        _buildFormField(_durationController, 'Duration'),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormField(
                                _categoryController,
                                'Category',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFormField(
                                _durationController,
                                'Duration',
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      if (isCompact) ...[
                        _buildFormField(
                          _ratingController,
                          'Rating',
                          keyboardType: TextInputType.number,
                          optional: true,
                        ),
                        const SizedBox(height: 20),
                        _buildFormField(
                          _priceController,
                          'Price (₹)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          optional: true,
                          prefixText: '₹ ',
                        ),
                        const SizedBox(height: 20),
                        _buildDifficultyField(),
                      ] else
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    _ratingController,
                                    'Rating',
                                    keyboardType: TextInputType.number,
                                    optional: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDifficultyField()),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildFormField(
                              _priceController,
                              'Price (₹)',
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              optional: true,
                              prefixText: '₹ ',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
              child: Wrap(
                alignment: WrapAlignment.end,
                runAlignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      overlayColor: Colors.grey.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool optional = false,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines == 1 ? 1 : maxLines,
          keyboardType: keyboardType,
          validator: optional
              ? null
              : (v) {
                  if (v == null || v.trim().isEmpty) return '$label is required';
                  return null;
                },
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF111827),
            height: 1.45,
          ),
          decoration: InputDecoration(
            prefixText: prefixText,
            prefixStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
          ),
          textAlignVertical: maxLines == 1 ? TextAlignVertical.center : null,
        ),
      ],
    );
  }

  Widget _buildDifficultyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Difficulty',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _difficulty,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Difficulty is required';
            return null;
          },
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
          ),
          items: const [
            DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
            DropdownMenuItem(
              value: 'intermediate',
              child: Text('Intermediate'),
            ),
            DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
          ],
          onChanged: (v) => setState(() => _difficulty = v ?? 'intermediate'),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
          isExpanded: true,
        ),
      ],
    );
  }
}
