import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:shimmer/shimmer.dart';

import '../admin_modules/course/index.dart';
import '../config/theme.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'add_course_screen.dart';

class ManageCourseScreen extends StatefulWidget {
  const ManageCourseScreen({super.key});

  @override
  State<ManageCourseScreen> createState() => _ManageCourseScreenState();
}

class _ManageCourseScreenState extends State<ManageCourseScreen> {
  late Future<void> _loadFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadCourses();
  }

  Future<void> _loadCourses() {
    return Provider.of<CourseProvider>(context, listen: false).loadCourses();
  }

  Future<void> _deleteCourse(Course course) async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
    });

    try {
      await ApiService.instance.deleteCourse(course.id);
      await _loadCourses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course deleted', style: GoogleFonts.poppins())),
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
          content: Text(
            'Failed to delete course',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
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
                    'Only admins can assign courses to mentors and students.',
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
                        'Manage Courses',
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.separated(
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) {
                          return Shimmer.fromColors(
                            baseColor: Colors.black.withOpacity(0.04),
                            highlightColor: Colors.white,
                            child: Container(
                              height: 120,
                              decoration: LmsAdminTheme.adminCardDecoration,
                            ),
                          );
                        },
                      );
                    }

                    final courses = context.watch<CourseProvider>().courses;

                    if (courses.isEmpty) {
                      return Center(
                        child: Text(
                          'No courses yet. Tap + to create one.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        return CourseCard(
                          course: course,
                          onDelete: () => _deleteCourse(course),
                          onView: () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => CourseViewDialog(course: course),
                            );
                          },
                          onEdit: () async {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => CourseEditDialog(course: course),
                            );
                            if (mounted) {
                              setState(() {
                                _loadFuture = _loadCourses();
                              });
                            }
                          },
                          onAssignments: () async {
                            final updated = await showDialog<bool>(
                              context: context,
                              builder: (_) => _CourseAssignmentsDialog(course: course),
                            );
                            if (updated == true && mounted) {
                              setState(() {
                                _loadFuture = _loadCourses();
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
        heroTag: 'manageCoursesFab',
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddCourseScreen()));
          // Reload after returning from add course
          setState(() {
            _loadFuture = _loadCourses();
          });
        },
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Course',
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

class _CourseAssignmentsDialog extends StatefulWidget {
  const _CourseAssignmentsDialog({required this.course});

  final Course course;

  @override
  State<_CourseAssignmentsDialog> createState() =>
      _CourseAssignmentsDialogState();
}

class _CourseAssignmentsDialogState extends State<_CourseAssignmentsDialog> {
  bool _loadingUsers = true;
  bool _saving = false;
  List<AppUser> _students = const [];
  List<AppUser> _mentors = const [];
  final Set<String> _selectedStudentIds = <String>{};
  final Set<String> _selectedMentorIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.loadUsers();

      final students = auth.students;
      final mentors = auth.mentors;

      if (!mounted) return;
      setState(() {
        _students = students;
        _mentors = mentors;
        _selectedStudentIds
          ..clear()
          ..addAll(
            students
                .where((u) => u.courseIds.contains(widget.course.id))
                .map((u) => u.id),
          );
        _selectedMentorIds
          ..clear()
          ..addAll(
            mentors
                .where((u) => u.courseIds.contains(widget.course.id))
                .map((u) => u.id),
          );
        _loadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _students = const [];
        _mentors = const [];
        _loadingUsers = false;
      });
    }
  }

  Future<void> _saveAssignments() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      Future<bool> updateUsers(
        List<AppUser> users,
        Set<String> selectedIds,
      ) async {
        var changed = false;
        for (final user in users) {
          final next = user.courseIds.toSet();
          final shouldContain = selectedIds.contains(user.id);
          if (shouldContain) {
            next.add(widget.course.id);
          } else {
            next.remove(widget.course.id);
          }

          if (next.length == user.courseIds.toSet().length &&
              next.containsAll(user.courseIds)) {
            continue;
          }

          changed = true;
          await ApiService.instance.updateUser(
            user.id,
            courseIds: next.toList(growable: false),
            includeCourseIds: true,
          );
        }

        return changed;
      }

      final studentChanged = await updateUsers(_students, _selectedStudentIds);
      final mentorChanged = await updateUsers(_mentors, _selectedMentorIds);

      try {
        await ApiService.instance.updateCourseDetails(
          widget.course.id,
          title: widget.course.title,
          description: widget.course.description,
          category: widget.course.category,
          duration: widget.course.duration,
          instructorName: widget.course.instructorName,
          thumbnailUrl: widget.course.thumbnailUrl,
          difficulty: widget.course.difficulty.name,
          rating: widget.course.rating,
          price: widget.course.price,
          mentorId: _selectedMentorIds.isEmpty ? null : _selectedMentorIds.first,
        );
      } on ApiException catch (e) {
        final message = e.message.toLowerCase();
        final isNoop = message.contains('no fields to update');
        if (!isNoop) rethrow;
      }

      await context.read<AuthProvider>().loadUsers();
      await context.read<AuthProvider>().refreshCurrentUser();
      await context.read<CourseProvider>().loadCourses();

      if (kDebugMode) {
        print('Course ${widget.course.id} assigned students: ${_selectedStudentIds.toList(growable: false)}');
        print('Course ${widget.course.id} assigned mentors: ${_selectedMentorIds.toList(growable: false)}');
        print('Course assignment changed: students=$studentChanged mentors=$mentorChanged');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: GoogleFonts.poppins())),
      );
      setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save course assignment', style: GoogleFonts.poppins()),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Course Assignment',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 560,
        child: _loadingUsers
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.course.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Assign Students',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _userChecklist(
                      users: _students,
                      selectedIds: _selectedStudentIds,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Assign Mentors',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _userChecklist(
                      users: _mentors,
                      selectedIds: _selectedMentorIds,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _saveAssignments,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: _saving
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

  Widget _userChecklist({
    required List<AppUser> users,
    required Set<String> selectedIds,
  }) {
    if (users.isEmpty) {
      return Text(
        'No users available',
        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final selected = selectedIds.contains(user.id);
          return CheckboxListTile(
            dense: true,
            value: selected,
            title: Text(
              user.name,
              style: GoogleFonts.poppins(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              user.email,
              style: GoogleFonts.poppins(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  selectedIds.add(user.id);
                } else {
                  selectedIds.remove(user.id);
                }
              });
            },
          );
        },
      ),
    );
  }
}
