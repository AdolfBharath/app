import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../models/batch.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'add_batch_screen.dart';
import 'batch_details_screen.dart';

class ManageBatchScreen extends StatefulWidget {
  const ManageBatchScreen({super.key});

  @override
  State<ManageBatchScreen> createState() => _ManageBatchScreenState();
}

class _ManageBatchScreenState extends State<ManageBatchScreen> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    // Defer loading to avoid calling during build phase
    _loadFuture = Future.microtask(() => _loadBatches());
  }

  Future<void> _loadBatches() {
    return Future.wait([
      Provider.of<BatchProvider>(context, listen: false).loadBatches(),
      Provider.of<AuthProvider>(context, listen: false).loadUsers(),
    ]).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F7FA);

    final courseProvider = context.read<CourseProvider>();
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
                    'Only admins can create, edit, and assign students to batches.',
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        'Manage Batches',
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
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<void>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    final batchProvider = context.watch<BatchProvider>();

                    if (snapshot.connectionState == ConnectionState.waiting ||
                        batchProvider.isLoading) {
                      return ListView.separated(
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) {
                          return Shimmer.fromColors(
                            baseColor: Colors.black.withOpacity(0.04),
                            highlightColor: Colors.white,
                            child: Container(
                              height: 160,
                              decoration: LmsAdminTheme.adminCardDecoration,
                            ),
                          );
                        },
                      );
                    }

                    // Show error if exists
                    if (batchProvider.errorMessage != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load batches',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                batchProvider.errorMessage ?? 'Unknown error',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _loadFuture = _loadBatches();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final batches = batchProvider.batches;

                    if (batches.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No batches yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to create your first batch',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final mentors = authProvider.mentors;
                    final students = authProvider.students;

                    return ListView.separated(
                      itemCount: batches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final batch = batches[index];
                        final course = courseProvider.getById(batch.courseId);
                        final mentor = mentors
                            .where((m) => m.id == batch.mentorId)
                            .cast<AppUser?>()
                            .firstWhere((m) => m != null, orElse: () => null);

                        final batchStudents = students
                            .where((s) => s.batchId == batch.id)
                            .toList();

                        return _BatchCard(
                          batch: batch,
                          courseName: course?.title,
                          mentorName: mentor?.name,
                          students: batchStudents,
                          onEditBatch: () async {
                            final updated = await showDialog<bool>(
                              context: context,
                              builder: (_) => _BatchEditDialog(
                                batch: batch,
                                initialStudents: students,
                                mentors: mentors,
                                courses: courseProvider.courses,
                              ),
                            );
                            if (updated == true && mounted) {
                              setState(() {
                                _loadFuture = _loadBatches();
                              });
                            }
                          },
                          onViewBatch: () {
                            Navigator.of(context).pushNamed(
                              BatchDetailsScreen.routeName,
                              arguments: batch.id,
                            );
                          },
                          onDeleteBatch: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(
                                    'Delete Batch',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete this batch?',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true || !context.mounted) return;

                            final ok = await context.read<BatchProvider>().deleteBatch(batch);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.read<BatchProvider>().errorMessage ?? 'Failed to delete batch',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Batch deleted', style: GoogleFonts.poppins()),
                                ),
                              );
                            }

                            if (context.mounted) {
                              setState(() {
                                _loadFuture = _loadBatches();
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manageBatchesFab',
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddBatchScreen()));
          setState(() {
            _loadFuture = _loadBatches();
          });
        },
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Batch',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.courseName,
    required this.mentorName,
    required this.students,
    required this.onEditBatch,
    required this.onViewBatch,
    required this.onDeleteBatch,
  });

  final Batch batch;
  final String? courseName;
  final String? mentorName;
  final List<AppUser> students;
  final VoidCallback onEditBatch;
  final VoidCallback onViewBatch;
  final VoidCallback onDeleteBatch;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted =
        batch.status.toLowerCase() == 'completed' ||
        batch.status.toLowerCase() == 'finished';
    final double progressValue = batch.progress > 0
        ? batch.progress.clamp(0.0, 1.0)
        : (batch.capacity != null && batch.capacity! > 0)
        ? (batch.enrolledCount / batch.capacity!).clamp(0.0, 1.0)
        : 0.0;
    final int progressPercent = (progressValue * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LmsAdminTheme.adminCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (courseName != null)
                      Text(
                        courseName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    if (mentorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Mentor: $mentorName',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF34D399),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  batch.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? const Color(0xFF374151)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                '$progressPercent%',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD7E7FF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${students.length} students',
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
            ],
          ),
          if (students.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 0; i < students.length && i < 3; i++)
                  Transform.translate(
                    offset: Offset(i == 0 ? 0 : -10.0 * i, 0),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        students[i].name.isNotEmpty
                            ? students[i].name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ),
                if (students.length > 3) ...[
                  const SizedBox(width: 4),
                  Text(
                    '+${students.length - 3}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.black.withOpacity(0.04)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _CardActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit Batch',
                color: const Color(0xFF1D4ED8),
                filled: false,
                onTap: onEditBatch,
              ),
              const SizedBox(width: 8),
              _CardActionButton(
                icon: Icons.visibility_outlined,
                label: 'View',
                color: const Color(0xFF3B82F6),
                filled: true,
                onTap: onViewBatch,
              ),
              const SizedBox(width: 8),
              _CardActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: const Color(0xFFDC2626),
                filled: false,
                onTap: onDeleteBatch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchEditDialog extends StatefulWidget {
  const _BatchEditDialog({
    required this.batch,
    required this.initialStudents,
    required this.mentors,
    required this.courses,
  });

  final Batch batch;
  final List<AppUser> initialStudents;
  final List<AppUser> mentors;
  final List<Course> courses;

  @override
  State<_BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<_BatchEditDialog> {
  late final TextEditingController _nameController;
  String? _selectedCourseId;
  String? _selectedMentorId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  List<_StudentAssignmentItem> _allStudents = const [];
  List<_StudentAssignmentItem> _autoMappedStudents = const [];
  final Set<String> _manuallyRemovedStudentIds = <String>{};
  final Set<String> _manuallyAddedStudentIds = <String>{};
  bool _loadingStudents = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.batch.name);
    _selectedCourseId = widget.batch.courseId;
    _selectedMentorId = widget.batch.mentorId;
    _startDate = widget.batch.startDate;
    _loadStudents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final raw = await ApiService.instance.getUsers(role: 'student');
      final all = raw.map(_StudentAssignmentItem.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _allStudents = all;
        _autoMappedStudents = _eligibleStudentsInternal(all, _selectedCourseId);
        _loadingStudents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allStudents = const [];
        _loadingStudents = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? (_startDate ?? now));
    final first = isStart ? now.subtract(const Duration(days: 365)) : (_startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _openAddStudentPicker() async {
    final selectedCourseId = _selectedCourseId;
    if (selectedCourseId == null || selectedCourseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select a course before adding students.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final currentTargetIds = {
      ..._currentBatchStudents().map((s) => s.id),
      ..._autoMappedStudents.map((s) => s.id),
      ..._manuallyAddedStudentIds,
    }.difference(_manuallyRemovedStudentIds);

    final candidates = _allStudents
        .where((s) => !currentTargetIds.contains(s.id))
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
                      'Selected students will also be assigned to this course automatically.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final s = candidates[index];
                          final isChecked = temp.contains(s.id);
                          return CheckboxListTile(
                            value: isChecked,
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
      _manuallyRemovedStudentIds.removeAll(selected);
      _manuallyAddedStudentIds.addAll(selected);
    });
  }

  List<_StudentAssignmentItem> _currentBatchStudents() {
    return _allStudents
        .where((s) => s.batchId == widget.batch.id)
        .toList(growable: false);
  }

  Future<void> _save() async {
    if (_saving) return;
    final selectedCourseId = _selectedCourseId;
    final name = _nameController.text.trim();
    if (name.isEmpty || selectedCourseId == null || selectedCourseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course selection is required', style: GoogleFonts.poppins())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      try {
        final batchUpdated = await ApiService.instance.updateBatch(
          batchId: widget.batch.id,
          name: name,
          courseId: selectedCourseId,
          mentorId: _selectedMentorId,
          startDate: _startDate,
          endDate: _endDate,
        );

        if (!batchUpdated) {
          throw Exception('Failed to update batch');
        }
      } on ApiException catch (e) {
        final message = e.message.toLowerCase();
        final isNoop = message.contains('no fields to update');
        if (!isNoop) {
          rethrow;
        }
      }

      final autoMappedIds = _eligibleStudentsInternal(
        _allStudents,
        selectedCourseId,
      ).map((s) => s.id).toSet();
      final currentBatchIds = _currentBatchStudents().map((s) => s.id).toSet();

      final courseChanged = selectedCourseId != widget.batch.courseId;
      final baselineIds = courseChanged ? autoMappedIds : currentBatchIds;

      final targetIds = {
        ...baselineIds,
        ..._manuallyAddedStudentIds,
      }.difference(_manuallyRemovedStudentIds);

      final toAssign = targetIds.difference(currentBatchIds);
      final toUnassign = currentBatchIds.difference(targetIds);

      for (final id in _manuallyAddedStudentIds) {
        final student = _allStudents.where((s) => s.id == id).cast<_StudentAssignmentItem?>().firstWhere((s) => s != null, orElse: () => null);
        if (student == null) continue;
        if (student.courseIds.contains(selectedCourseId)) continue;

        final nextCourseIds = {...student.courseIds, selectedCourseId}.toList(growable: false);
        await ApiService.instance.updateUser(
          id,
          courseIds: nextCourseIds,
          includeCourseIds: true,
        );
      }

      for (final id in toAssign) {
        await ApiService.instance.updateUser(
          id,
          batchId: widget.batch.id,
          includeBatchId: true,
        );
      }

      for (final id in toUnassign) {
        await ApiService.instance.updateUser(
          id,
          batchId: null,
          includeBatchId: true,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save batch: $e', style: GoogleFonts.poppins())),
      );
      setState(() => _saving = false);
    }
  }

  List<_StudentAssignmentItem> _eligibleStudentsInternal(
    List<_StudentAssignmentItem> source,
    String? selectedCourseId,
  ) {
    if (selectedCourseId == null || selectedCourseId.isEmpty) return const [];
    return source
        .where((s) => s.courseIds.any((cid) => cid == selectedCourseId))
        .toList(growable: false);
  }

  List<_StudentAssignmentItem> _eligibleStudents() {
    return _eligibleStudentsInternal(_allStudents, _selectedCourseId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Batch',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Batch Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                decoration: const InputDecoration(labelText: 'Assigned Course'),
                items: widget.courses
                    .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.title, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedCourseId = v;
                    _autoMappedStudents = _eligibleStudents();
                    _manuallyAddedStudentIds.clear();
                    _manuallyRemovedStudentIds.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedMentorId,
                decoration: const InputDecoration(labelText: 'Mentor'),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Unassigned')),
                  ...widget.mentors.map((m) => DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedMentorId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_startDate == null ? 'Start Date' : _fmtDate(_startDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(_endDate == null ? 'End Date' : _fmtDate(_endDate!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Auto-Mapped Students (by selected course)',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (!_loadingStudents)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _openAddStudentPicker,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add Student'),
                  ),
                ),
              if (!_loadingStudents) const SizedBox(height: 8),
              if (_loadingStudents)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_autoMappedStudents.isEmpty)
                Text(
                  'No eligible students found for this course.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _autoMappedStudents.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: const Color(0xFFE5E7EB).withOpacity(0.8),
                    ),
                    itemBuilder: (context, index) {
                      final s = _autoMappedStudents[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        title: Text(s.name, style: GoogleFonts.poppins(fontSize: 12)),
                        subtitle: Text(s.email, style: GoogleFonts.poppins(fontSize: 11)),
                        trailing: Text(
                          'Auto',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Current Batch Students',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_currentBatchStudents().isEmpty)
                Text(
                  'No students currently in this batch.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _currentBatchStudents().map((student) {
                      final removed = _manuallyRemovedStudentIds.contains(student.id);
                      return ListTile(
                        dense: true,
                        title: Text(
                          student.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            decoration: removed ? TextDecoration.lineThrough : null,
                            color: removed ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Text(
                          student.email,
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                        trailing: IconButton(
                          tooltip: removed ? 'Undo remove' : 'Remove from batch',
                          onPressed: () {
                            setState(() {
                              if (removed) {
                                _manuallyRemovedStudentIds.remove(student.id);
                              } else {
                                _manuallyRemovedStudentIds.add(student.id);
                                _manuallyAddedStudentIds.remove(student.id);
                              }
                            });
                          },
                          icon: Icon(
                            removed ? Icons.restore_from_trash_outlined : Icons.delete_outline,
                            size: 18,
                            color: removed ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              if (_manuallyAddedStudentIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Manually Added Students',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _manuallyAddedStudentIds.map((id) {
                      final student = _allStudents
                          .where((s) => s.id == id)
                          .cast<_StudentAssignmentItem?>()
                          .firstWhere((s) => s != null, orElse: () => null);
                      if (student == null) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        dense: true,
                        title: Text(
                          student.name,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        subtitle: Text(
                          student.email,
                          style: GoogleFonts.poppins(fontSize: 11),
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
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _StudentAssignmentItem {
  const _StudentAssignmentItem({
    required this.id,
    required this.name,
    required this.email,
    required this.courseIds,
    required this.batchId,
  });

  final String id;
  final String name;
  final String email;
  final List<String> courseIds;
  final String? batchId;

  factory _StudentAssignmentItem.fromJson(Map<String, dynamic> json) {
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

    return _StudentAssignmentItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Student').toString(),
      email: (json['email'] ?? '').toString(),
      courseIds: rawCourses.toList(growable: false),
      batchId: json['batch_id']?.toString() ?? json['batchId']?.toString(),
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
          horizontal: compact ? 14 : 16,
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
