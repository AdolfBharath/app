import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({super.key});

  static const routeName = '/admin/add-batch';

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();

  String? _selectedCourseId;
  String? _selectedMentorId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _smartWaitlist = false;
  bool _saving = false;
  List<_BatchStudentAssignmentItem> _allStudents = const [];
  List<_BatchStudentAssignmentItem> _autoMappedStudents = const [];
  final Set<String> _manuallyAddedStudentIds = <String>{};
  bool _loadingAutoMappedStudents = false;

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final courseId = _selectedCourseId!;

    int? capacity;
    if (_capacityController.text.trim().isNotEmpty) {
      capacity = int.tryParse(_capacityController.text.trim());
    }

    setState(() {
      _saving = true;
    });

    final batchProvider = context.read<BatchProvider>();

    final success = await batchProvider.addBatch(
      name: name,
      courseId: courseId,
      mentorId: _selectedMentorId,
      capacity: capacity,
      smartWaitlist: _smartWaitlist,
      startDate: _startDate,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (success) {
      await batchProvider.loadBatches();
      final created = batchProvider.batches
          .where((b) => b.name.trim() == name && b.courseId == courseId)
          .toList()
        ..sort((a, b) {
          final ad = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

      if (created.isNotEmpty) {
        final batchId = created.first.id;

        final targetIds = {
          ..._autoMappedStudents.map((s) => s.id),
          ..._manuallyAddedStudentIds,
        };

        for (final id in _manuallyAddedStudentIds) {
          final student = _allStudents
              .where((s) => s.id == id)
              .cast<_BatchStudentAssignmentItem?>()
              .firstWhere((s) => s != null, orElse: () => null);
          if (student == null) continue;
          if (student.courseIds.contains(courseId)) continue;

          final nextCourseIds = {...student.courseIds, courseId}.toList(growable: false);
          await ApiService.instance.updateUser(
            id,
            courseIds: nextCourseIds,
            includeCourseIds: true,
          );
        }

        for (final studentId in targetIds) {
          await ApiService.instance.updateUser(
            studentId,
            batchId: batchId,
            includeBatchId: true,
          );
        }

        await context.read<AuthProvider>().loadUsers();

        if (kDebugMode) {
          print('Batch $batchId mapped auto=${_autoMappedStudents.length} manual=${_manuallyAddedStudentIds.length}');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batch created. ${_autoMappedStudents.length} auto + ${_manuallyAddedStudentIds.length} manual students mapped.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create batch', style: GoogleFonts.poppins()),
        ),
      );
    }
  }

  Future<void> _loadAutoMappedStudents(String? courseId) async {
    if (courseId == null || courseId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _allStudents = const [];
        _autoMappedStudents = const [];
        _manuallyAddedStudentIds.clear();
        _loadingAutoMappedStudents = false;
      });
      return;
    }

    setState(() {
      _loadingAutoMappedStudents = true;
    });

    try {
      final raw = await ApiService.instance.getUsers(role: 'student');
      final mapped = raw
          .map(_BatchStudentAssignmentItem.fromJson)
          .where((u) => u.id.isNotEmpty)
          .toList(growable: false);

      final autoMapped = mapped
          .where((s) => s.courseIds.contains(courseId))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _allStudents = mapped;
        _autoMappedStudents = autoMapped;
        _manuallyAddedStudentIds.clear();
        _loadingAutoMappedStudents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allStudents = const [];
        _autoMappedStudents = const [];
        _manuallyAddedStudentIds.clear();
        _loadingAutoMappedStudents = false;
      });
    }
  }

  Future<void> _openAddStudentPicker() async {
    final selectedCourseId = _selectedCourseId;
    if (selectedCourseId == null || selectedCourseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a course first.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final alreadyIncludedIds = {
      ..._autoMappedStudents.map((s) => s.id),
      ..._manuallyAddedStudentIds,
    };

    final candidates = _allStudents
        .where((s) => !alreadyIncludedIds.contains(s.id))
        .toList(growable: false);

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No additional students available.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final temp = <String>{};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Students Manually',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manual students will be assigned to the selected course automatically.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final s = candidates[index];
                          final checked = temp.contains(s.id);
                          return CheckboxListTile(
                            value: checked,
                            dense: true,
                            title: Text(
                              s.name,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            subtitle: Text(
                              s.email,
                              style: GoogleFonts.poppins(fontSize: 11),
                            ),
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  temp.add(s.id);
                                } else {
                                  temp.remove(s.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(temp),
                            child: const Text('Add Selected'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null || selected.isEmpty) return;
    setState(() {
      _manuallyAddedStudentIds.addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F7FA);

    final courseProvider = context.watch<CourseProvider>();
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
                  const Icon(Icons.lock_outline_rounded, size: 52, color: Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  Text(
                    'Admin access required',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final courses = courseProvider.courses;
    final mentors = authProvider.mentors;

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
                Text(
                  'Create Batch',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
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
                    letterSpacing: 1.1,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 16),

                // Batch identity card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
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
                              Icons.layers_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Batch identity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Define how this cohort will appear across the LMS.',
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
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'BATCH NAME *',
                        child: TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            "e.g. UX Design Immersive '26",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a batch name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Recommended: [Course Name] + [Term/Year]",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'ASSOCIATED COURSE *',
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCourseId,
                          isExpanded: true,
                          decoration: _inputDecoration('Choose course'),
                          items: courses
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    c.title,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCourseId = value;
                            });
                            _loadAutoMappedStudents(value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a course';
                            }
                            return null;
                          },
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
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Mapped Students',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Students assigned to the selected course will be mapped automatically.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingAutoMappedStudents)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Students to map: ${_autoMappedStudents.length + _manuallyAddedStudentIds.length}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openAddStudentPicker,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Add Student'),
                            ),
                          ],
                        ),
                      if (_autoMappedStudents.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            itemCount: _autoMappedStudents.length,
                            itemBuilder: (context, index) {
                              final s = _autoMappedStudents[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${s.name} • ${s.email}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF4B5563),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (_manuallyAddedStudentIds.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Manual Additions',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView(
                            children: _manuallyAddedStudentIds.map((id) {
                              final s = _allStudents
                                  .where((u) => u.id == id)
                                  .cast<_BatchStudentAssignmentItem?>()
                                  .firstWhere((u) => u != null, orElse: () => null);
                              if (s == null) return const SizedBox.shrink();
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${s.name} • ${s.email}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                                trailing: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _manuallyAddedStudentIds.remove(id);
                                    });
                                  },
                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Mentorship & logistics card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
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
                              Icons.groups_2_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mentorship & Logistics',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Configure mentor assignment and time period.',
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
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'LEAD MENTOR',
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMentorId,
                          isExpanded: true,
                          decoration: _inputDecoration('Assign mentor'),
                          items: mentors
                              .map(
                                (m) => DropdownMenuItem<String>(
                                  value: m.id,
                                  child: Text(
                                    m.name,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMentorId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'CAPACITY',
                        child: TextFormField(
                          controller: _capacityController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('25'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'START DATE',
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? now,
                              firstDate: now.subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: now.add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _startDate == null
                                      ? 'Select start date'
                                      : _formatDate(_startDate!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'END DATE (optional)',
                        child: InkWell(
                          onTap: () async {
                            final base = _startDate ?? DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? base,
                              firstDate: base,
                              lastDate: base.add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _endDate == null
                                      ? 'Select end date'
                                      : _formatDate(_endDate!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFEFF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Switch.adaptive(
                              value: _smartWaitlist,
                              onChanged: (value) {
                                setState(() {
                                  _smartWaitlist = value;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Smart Waitlist',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Automatically controls overflow handling for admin-managed assignments.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'By confirming, you authorize the allocation of server resources for this training batch.',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                Navigator.of(context).maybePop();
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Create Batch',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchStudentAssignmentItem {
  const _BatchStudentAssignmentItem({
    required this.id,
    required this.name,
    required this.email,
    required this.courseIds,
  });

  final String id;
  final String name;
  final String email;
  final List<String> courseIds;

  factory _BatchStudentAssignmentItem.fromJson(Map<String, dynamic> json) {
    final rawCourses = <String>{};

    void addCourseId(dynamic v) {
      if (v == null) return;
      final id = v.toString().trim();
      if (id.isNotEmpty) rawCourses.add(id);
    }

    addCourseId(json['course_id']);
    addCourseId(json['courseId']);
    addCourseId(json['enrolled_course_id']);

    final rawCourseIds = json['course_ids'];
    if (rawCourseIds is List) {
      for (final c in rawCourseIds) {
        addCourseId(c);
      }
    }

    final courses = json['courses'];
    if (courses is List) {
      for (final c in courses) {
        if (c is Map<String, dynamic>) {
          addCourseId(c['id']);
          addCourseId(c['course_id']);
        } else {
          addCourseId(c);
        }
      }
    }

    return _BatchStudentAssignmentItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Student').toString(),
      email: (json['email'] ?? '').toString(),
      courseIds: rawCourses.toList(growable: false),
    );
  }
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
