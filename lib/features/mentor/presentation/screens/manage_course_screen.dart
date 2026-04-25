import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../models/course.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_service.dart';
import '../../../../screens/login_screen.dart';
import 'mentor_create_announcement_screen.dart';
import 'mentor_notifications_screen.dart';
import '../providers/mentor_provider.dart';
import '../../../../config/theme.dart';

bool _isValidDriveLink(String link) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  return uri.host.toLowerCase().contains('drive.google.com');
}

class ManageCourseScreen extends StatefulWidget {
  const ManageCourseScreen({super.key, required this.username});

  final String username;

  @override
  State<ManageCourseScreen> createState() => _ManageCourseScreenState();
}

class _ManageCourseScreenState extends State<ManageCourseScreen> {
  String _courseFilter = 'All';

  Future<void> _showEditCourseModal(Course course) async {
    final selectedOption = await showModalBottomSheet<_EditCourseOption>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditCourseOptionsSheet(course: course),
    );

    if (selectedOption == null || !mounted) return;

    bool? saved;
    switch (selectedOption) {
      case _EditCourseOption.details:
        saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _EditCourseDetailsBottomSheet(course: course),
        );
        break;
      case _EditCourseOption.modules:
        saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _EditCourseBottomSheet(course: course),
        );
        break;
      case _EditCourseOption.studyMaterials:
        saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _StudyMaterialBottomSheet(course: course),
        );
        break;
      case _EditCourseOption.quiz:
        saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _QuizEditorBottomSheet(course: course),
        );
        break;
    }

    if (saved == true && mounted) {
      await context.read<MentorProvider>().loadAll();
    }
  }

  void _showViewCourseModal(Course course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ViewCourseBottomSheet(course: course),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mentorProvider = context.watch<MentorProvider>();
    final allCourses = mentorProvider.courses;

    // Filter courses based on status. If status isn't reliable, just fall back gracefully
    final filteredCourses = allCourses.where((c) {
      if (_courseFilter == 'All') {
        return true;
      }
      if (_courseFilter == 'Published') {
        return c.status.toLowerCase() == 'published';
      } else {
        return c.status.toLowerCase() == 'review' ||
            c.status.toLowerCase() == 'in review';
      }
    }).toList();

    return SafeArea(
      child: Scaffold(
        backgroundColor: LmsAdminTheme.backgroundLight,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                              'Courses',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: LmsAdminTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage curriculum & content',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _MentorActionIcon(
                              icon: Icons.campaign_outlined,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MentorCreateAnnouncementScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _MentorActionIcon(
                              icon: Icons.notifications_none_rounded,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MentorNotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _MentorActionIcon(
                              icon: Icons.logout_rounded,
                              onTap: () {
                                final auth = context.read<AuthProvider>();
                                auth.logout();
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  LoginScreen.routeName,
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: LmsAdminTheme.adminCardDecoration(context),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Color(0xFF3B82F6),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Courses',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${allCourses.length} courses • 140+ students',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Courses',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _MentorFilterChip(
                                label: 'All',
                                isSelected: _courseFilter == 'All',
                                onSelected: (val) {
                                  setState(() => _courseFilter = 'All');
                                },
                              ),
                              const SizedBox(width: 8),
                              _MentorFilterChip(
                                label: 'Published',
                                isSelected: _courseFilter == 'Published',
                                onSelected: (val) {
                                  setState(() => _courseFilter = 'Published');
                                },
                              ),
                              const SizedBox(width: 8),
                              _MentorFilterChip(
                                label: 'Review',
                                isSelected: _courseFilter == 'Review',
                                onSelected: (val) {
                                  setState(() => _courseFilter = 'Review');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Course List
            if (filteredCourses.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          color: Color(0xFF3B82F6),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No courses found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try adjusting your filters',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final course = filteredCourses[index];
                    return _CourseItemCard(
                      course: course,
                      onView: () => _showViewCourseModal(course),
                      onEdit: () => _showEditCourseModal(course),
                    );
                  }, childCount: filteredCourses.length),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _MentorFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _MentorFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentorActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MentorActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _CourseItemCard extends StatelessWidget {
  final Course course;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _CourseItemCard({
    required this.course,
    required this.onView,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF3B82F6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${course.rating} ⭐',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.description,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  child: _MentorActionButton(
                    label: 'View',
                    icon: Icons.visibility_outlined,
                    onTap: onView,
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MentorActionButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _MentorActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF3B82F6) : Colors.white,
            border: isPrimary
                ? null
                : Border.all(color: const Color(0xFFE2E8F0), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Sheets
// ---------------------------------------------------------------------------

enum _EditCourseOption { details, modules, studyMaterials, quiz }

class _EditCourseOptionsSheet extends StatelessWidget {
  const _EditCourseOptionsSheet({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final options = <_EditOptionItem>[
      const _EditOptionItem(
        option: _EditCourseOption.details,
        title: 'Edit Details',
        description: 'Update name, duration, image, type, and description.',
        icon: Icons.edit_note_rounded,
        color: Color(0xFF2563EB),
      ),
      const _EditOptionItem(
        option: _EditCourseOption.modules,
        title: 'Add Modules',
        description: 'Manage modules with lesson title, video link, transcript and duration.',
        icon: Icons.menu_book_rounded,
        color: Color(0xFF0EA5A4),
      ),
      const _EditOptionItem(
        option: _EditCourseOption.studyMaterials,
        title: 'Add Study Material',
        description: 'Attach PDFs, PPTs, images, or Drive links by module.',
        icon: Icons.description_outlined,
        color: Color(0xFF7C3AED),
      ),
      const _EditOptionItem(
        option: _EditCourseOption.quiz,
        title: 'Add Quiz',
        description: 'Create module quiz questions with answer keys.',
        icon: Icons.quiz_outlined,
        color: Color(0xFFEA580C),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Course Options',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              course.title,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ...options.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EditOptionTile(item: item),
                )),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _EditOptionItem {
  const _EditOptionItem({
    required this.option,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final _EditCourseOption option;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class _EditOptionTile extends StatelessWidget {
  const _EditOptionTile({required this.item});

  final _EditOptionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pop(item.option),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditCourseDetailsBottomSheet extends StatefulWidget {
  const _EditCourseDetailsBottomSheet({required this.course});

  final Course course;

  @override
  State<_EditCourseDetailsBottomSheet> createState() => _EditCourseDetailsBottomSheetState();
}

class _EditCourseDetailsBottomSheetState extends State<_EditCourseDetailsBottomSheet> {
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late final TextEditingController _thumbnail;
  late final TextEditingController _mentorName;
  String _moduleType = 'Self-paced';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.course.title);
    _duration = TextEditingController(text: widget.course.duration);
    _description = TextEditingController(text: widget.course.description);
    _thumbnail = TextEditingController(text: widget.course.thumbnailUrl);
    _mentorName = TextEditingController(text: widget.course.instructorName);
    _moduleType = widget.course.moduleType.isEmpty ? 'Self-paced' : widget.course.moduleType;
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _description.dispose();
    _thumbnail.dispose();
    _mentorName.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _existingModulePayload() {
    return widget.course.modules
        .map((m) => _EditableModule.fromCourseModule(m).toJson(courseId: widget.course.id))
        .toList(growable: false);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course name and description are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateCourseDetails(
        widget.course.id,
        title: _title.text.trim(),
        duration: _duration.text.trim(),
        description: _description.text.trim(),
        thumbnailUrl: _thumbnail.text.trim(),
        instructorName: _mentorName.text.trim().isEmpty ? 'Academy Mentor' : _mentorName.text.trim(),
        moduleType: _moduleType,
        category: widget.course.category,
        difficulty: widget.course.difficulty.name,
        rating: widget.course.rating,
        modules: _existingModulePayload(),
        price: widget.course.price,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update details: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Details',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Course Name')),
                      const SizedBox(height: 10),
                      TextField(controller: _duration, decoration: const InputDecoration(labelText: 'Course Duration')),
                      const SizedBox(height: 10),
                      TextField(controller: _description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Course Description')),
                      const SizedBox(height: 10),
                      TextField(controller: _thumbnail, decoration: const InputDecoration(labelText: 'Course Image URL')),
                      const SizedBox(height: 10),
                      TextField(controller: _mentorName, decoration: const InputDecoration(labelText: 'Mentor Name')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _moduleType,
                        items: const [
                          DropdownMenuItem(value: 'Live', child: Text('Live')),
                          DropdownMenuItem(value: 'Self-paced', child: Text('Self-paced')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _moduleType = value);
                        },
                        decoration: const InputDecoration(labelText: 'Course Type'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditCourseBottomSheet extends StatefulWidget {
  const _EditCourseBottomSheet({required this.course});

  final Course course;

  @override
  State<_EditCourseBottomSheet> createState() => _EditCourseBottomSheetState();
}

class _EditCourseBottomSheetState extends State<_EditCourseBottomSheet> {
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late final TextEditingController _thumbnail;
  late final TextEditingController _mentorName;
  late final TextEditingController _category;
  String _moduleType = 'Self-paced';
  bool _saving = false;
  late List<_EditableModule> _modules;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.course.title);
    _duration = TextEditingController(text: widget.course.duration);
    _description = TextEditingController(text: widget.course.description);
    _thumbnail = TextEditingController(text: widget.course.thumbnailUrl);
    _mentorName = TextEditingController(text: widget.course.instructorName);
    _category = TextEditingController(text: widget.course.category);
    _moduleType = widget.course.moduleType.isEmpty ? 'Self-paced' : widget.course.moduleType;
    _modules = widget.course.modules
      .map((m) => _EditableModule.fromCourseModule(m))
      .toList(growable: true);
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _description.dispose();
    _thumbnail.dispose();
    _mentorName.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _addOrEditModule({_EditableModule? module, int? index}) async {
    final orderIndex = TextEditingController(
      text: (module?.orderIndex ?? (_modules.length + 1)).toString(),
    );
    final title = TextEditingController(text: module?.title ?? '');
    final moduleDescription = TextEditingController(text: module?.description ?? '');
    final coinReward = TextEditingController(text: (module?.coinReward ?? 0).toString());
    
    // Copy lessons to edit locally
    List<_EditableLesson> localLessons = List<_EditableLesson>.from(module?.lessons ?? []);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(module == null ? 'Add Module' : 'Edit Module'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: orderIndex,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Module Order Index'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Module Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: moduleDescription,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Module Description'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: coinReward,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Module Reward (coins)'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lessons', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          final newLesson = await _addOrEditLessonDialog(context);
                          if (newLesson != null) {
                            setLocal(() => localLessons.add(newLesson));
                          }
                        },
                      ),
                    ],
                  ),
                  if (localLessons.isEmpty)
                    const Text('No lessons added yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ...localLessons.asMap().entries.map((entry) {
                      final lIdx = entry.key;
                      final l = entry.value;
                      return ListTile(
                        title: Text(l.title, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(l.duration, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final edited = await _addOrEditLessonDialog(context, lesson: l);
                                if (edited != null) {
                                  setLocal(() => localLessons[lIdx] = edited);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => setLocal(() => localLessons.removeAt(lIdx)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final parsedOrderIndex = int.tryParse(orderIndex.text.trim()) ?? (_modules.length + 1);
      final next = _EditableModule(
        id: module?.id ?? '',
        orderIndex: parsedOrderIndex,
        title: title.text.trim(),
        description: moduleDescription.text.trim(),
        lessons: localLessons,
        coinReward: int.tryParse(coinReward.text.trim()) ?? 0,
        studyMaterials: List<_StudyMaterialDraft>.from(module?.studyMaterials ?? const []),
        quizQuestions: List<_QuizQuestionDraft>.from(module?.quizQuestions ?? const []),
      );
      setState(() {
        if (index != null) {
          _modules[index] = next;
        } else {
          _modules.add(next);
        }
      });
    }

    orderIndex.dispose();
    title.dispose();
    moduleDescription.dispose();
    coinReward.dispose();
  }

  Future<_EditableLesson?> _addOrEditLessonDialog(BuildContext context, {_EditableLesson? lesson}) async {
    final title = TextEditingController(text: lesson?.title ?? '');
    final drive = TextEditingController(text: lesson?.videoDriveLink ?? '');
    final transcript = TextEditingController(text: lesson?.transcript ?? '');
    final duration = TextEditingController(text: lesson?.duration ?? '');
    final order = TextEditingController(text: (lesson?.orderIndex ?? 1).toString());

    return showDialog<_EditableLesson>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson == null ? 'Add Lesson' : 'Edit Lesson'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Lesson Title')),
              const SizedBox(height: 10),
              TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order Index')),
              const SizedBox(height: 10),
              TextField(controller: drive, decoration: const InputDecoration(labelText: 'Google Drive Link')),
              const SizedBox(height: 10),
              TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duration (e.g. 10m)')),
              const SizedBox(height: 10),
              TextField(controller: transcript, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Transcript')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final link = drive.text.trim();
              if (link.isNotEmpty && !_isValidDriveLink(link)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Drive link')));
                return;
              }
              Navigator.of(context).pop(_EditableLesson(
                id: lesson?.id ?? '',
                title: title.text.trim(),
                videoDriveLink: link,
                transcript: transcript.text.trim(),
                duration: duration.text.trim(),
                orderIndex: int.tryParse(order.text.trim()) ?? 1,
              ));
            },
            child: const Text('Save Lesson'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course name and description are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final modulePayload = _modules.map((m) => m.toJson(courseId: widget.course.id)).toList(growable: false);
      await ApiService.instance.updateCourseDetails(
        widget.course.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category.text.trim().isEmpty ? 'Development' : _category.text.trim(),
        duration: _duration.text.trim(),
        moduleType: _moduleType,
        instructorName: _mentorName.text.trim().isEmpty ? 'Academy Mentor' : _mentorName.text.trim(),
        thumbnailUrl: _thumbnail.text.trim(),
        difficulty: widget.course.difficulty.name,
        rating: widget.course.rating,
        modules: modulePayload,
        price: widget.course.price,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update course: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Modules',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Course Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _duration,
                        decoration: const InputDecoration(labelText: 'Course Duration'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _mentorName,
                        decoration: const InputDecoration(labelText: 'Course Mentor Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _thumbnail,
                        decoration: const InputDecoration(labelText: 'Course Image URL'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _moduleType,
                        items: const [
                          DropdownMenuItem(value: 'Live', child: Text('Live')),
                          DropdownMenuItem(value: 'Self-paced', child: Text('Self-paced')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _moduleType = value);
                        },
                        decoration: const InputDecoration(labelText: 'Module Type'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: 'Course Description'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Modules',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _addOrEditModule(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Module'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_modules.isEmpty)
                        Text(
                          'No modules yet. Add modules and lessons with Google Drive video links.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _modules.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _modules.removeAt(oldIndex);
                              _modules.insert(newIndex, item);
                              // Update order indices
                              for (int i = 0; i < _modules.length; i++) {
                                final m = _modules[i];
                                _modules[i] = _EditableModule(
                                  id: m.id,
                                  orderIndex: i + 1,
                                  title: m.title,
                                  description: m.description,
                                  lessons: m.lessons,
                                  coinReward: m.coinReward,
                                  studyMaterials: m.studyMaterials,
                                  quizQuestions: m.quizQuestions,
                                );
                              }
                            });
                          },
                          itemBuilder: (context, idx) {
                            final module = _modules[idx];
                            return Container(
                              key: ValueKey(module.id.isNotEmpty ? module.id : 'temp_$idx'),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.drag_indicator, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Module ${idx + 1}: ${module.title}',
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                            ),
                                            if (module.description.isNotEmpty)
                                              Text(
                                                module.description,
                                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _addOrEditModule(module: module, index: idx),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() => _modules.removeAt(idx)),
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                      ),
                                    ],
                                  ),
                                  if (module.lessons.isNotEmpty) ...[
                                    const Divider(),
                                    ...module.lessons.map((l) => Padding(
                                      padding: const EdgeInsets.only(left: 32.0, top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.play_circle_outline, size: 14, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${l.orderIndex}. ${l.title} (${l.duration})',
                                              style: GoogleFonts.poppins(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableLesson {
  _EditableLesson({
    required this.id,
    required this.title,
    required this.videoDriveLink,
    required this.transcript,
    required this.duration,
    required this.orderIndex,
  });

  factory _EditableLesson.fromCourseLesson(CourseLesson lesson) {
    return _EditableLesson(
      id: lesson.id,
      title: lesson.title,
      videoDriveLink: lesson.videoDriveLink,
      transcript: lesson.transcript,
      duration: lesson.duration,
      orderIndex: lesson.orderIndex,
    );
  }

  final String id;
  final String title;
  final String videoDriveLink;
  final String transcript;
  final String duration;
  final int orderIndex;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video_drive_link': videoDriveLink,
      'transcript': transcript,
      'duration': duration,
      'order_index': orderIndex,
    };
  }
}

class _EditableModule {
  _EditableModule({
    required this.id,
    required this.orderIndex,
    required this.title,
    required this.description,
    this.lessons = const [],
    this.coinReward = 0,
    this.studyMaterials = const [],
    this.quizQuestions = const [],
  });

  factory _EditableModule.fromCourseModule(CourseModule module) {
    return _EditableModule(
      id: module.id,
      orderIndex: module.orderIndex,
      title: module.title,
      description: module.description,
      lessons: module.lessons
          .map((l) => _EditableLesson.fromCourseLesson(l))
          .toList(growable: true),
      coinReward: module.coinReward,
      studyMaterials: module.studyMaterials
          .map((m) => _StudyMaterialDraft(
                title: m.title,
                description: m.description,
                driveLink: m.driveLink,
                fileName: m.fileName,
                fileType: m.fileType,
              ))
          .toList(growable: true),
      quizQuestions: module.quizQuestions
          .map((q) => _QuizQuestionDraft(
                question: q.question,
                optionA: q.optionA,
                optionB: q.optionB,
                optionC: q.optionC,
                optionD: q.optionD,
                correctAnswer: q.correctAnswer,
              ))
          .toList(growable: true),
    );
  }

  final String id;
  final int orderIndex;
  final String title;
  final String description;
  final List<_EditableLesson> lessons;
  final int coinReward;
  final List<_StudyMaterialDraft> studyMaterials;
  final List<_QuizQuestionDraft> quizQuestions;

  Map<String, dynamic> toJson({required String courseId}) {
    return {
      'id': id,
      'courseId': courseId,
      'order_index': orderIndex,
      'title': title,
      'description': description,
      'lessons': lessons.map((l) => l.toJson()).toList(growable: false),
      'coinReward': coinReward,
      'studyMaterials': studyMaterials.map((m) => m.toJson()).toList(growable: false),
      'quizQuestions': quizQuestions.map((q) => q.toJson()).toList(growable: false),
    };
  }
}

class _StudyMaterialDraft {
  _StudyMaterialDraft({
    required this.title,
    this.description = '',
    this.driveLink = '',
    this.fileName = '',
    this.fileType = '',
  });

  final String title;
  final String description;
  final String driveLink;
  final String fileName;
  final String fileType;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'driveLink': driveLink,
      'fileName': fileName,
      'fileType': fileType,
    };
  }
}

class _QuizQuestionDraft {
  _QuizQuestionDraft({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
  });

  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'optionA': optionA,
      'optionB': optionB,
      'optionC': optionC,
      'optionD': optionD,
      'correctAnswer': correctAnswer,
    };
  }
}

class _StudyMaterialBottomSheet extends StatefulWidget {
  const _StudyMaterialBottomSheet({required this.course});

  final Course course;

  @override
  State<_StudyMaterialBottomSheet> createState() => _StudyMaterialBottomSheetState();
}

class _StudyMaterialBottomSheetState extends State<_StudyMaterialBottomSheet> {
  late List<_EditableModule> _modules;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _modules = widget.course.modules
        .map((m) => _EditableModule.fromCourseModule(m))
        .toList(growable: true);
  }

  Future<void> _addMaterial(int moduleIndex) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final driveLink = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add Study Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(
                  controller: driveLink,
                  decoration: const InputDecoration(labelText: 'Drive Link (required)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final link = driveLink.text.trim();
      if (link.isEmpty || !_isValidDriveLink(link)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add a valid Google Drive link for study material.')),
          );
        }
        return;
      }

      final next = _StudyMaterialDraft(
        title: title.text.trim(),
        description: description.text.trim(),
        driveLink: link,
        fileName: '',
        fileType: '',
      );
      if (next.title.isNotEmpty) {
        setState(() {
          final materials = List<_StudyMaterialDraft>.from(_modules[moduleIndex].studyMaterials)..add(next);
          final module = _modules[moduleIndex];
          _modules[moduleIndex] = _EditableModule(
            id: module.id,
            orderIndex: module.orderIndex,
            title: module.title,
            description: module.description,
            lessons: module.lessons,
            coinReward: module.coinReward,
            studyMaterials: materials,
            quizQuestions: module.quizQuestions,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateCourseDetails(
        widget.course.id,
        title: widget.course.title,
        description: widget.course.description,
        category: widget.course.category,
        duration: widget.course.duration,
        moduleType: widget.course.moduleType,
        instructorName: widget.course.instructorName,
        thumbnailUrl: widget.course.thumbnailUrl,
        difficulty: widget.course.difficulty.name,
        rating: widget.course.rating,
        price: widget.course.price,
        modules: _modules.map((m) => m.toJson(courseId: widget.course.id)).toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save study materials: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Study Material', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: _modules.isEmpty
                    ? Center(
                        child: Text(
                          'Add modules first to attach study materials.',
                          style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _modules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final module = _modules[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Module ${module.orderIndex}: ${module.title}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _addMaterial(index),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (module.studyMaterials.isEmpty)
                                  Text('No materials yet', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)))
                                else
                                  ...module.studyMaterials.asMap().entries.map((entry) {
                                    final mIndex = entry.key;
                                    final material = entry.value;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: const Icon(Icons.attach_file, size: 18),
                                      title: Text(material.title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        material.driveLink.isNotEmpty ? material.driveLink : (material.fileName.isEmpty ? 'No link/file' : material.fileName),
                                        style: GoogleFonts.poppins(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            final next = List<_StudyMaterialDraft>.from(module.studyMaterials)..removeAt(mIndex);
                                            _modules[index] = _EditableModule(
                                              id: module.id,
                                              orderIndex: module.orderIndex,
                                              title: module.title,
                                              description: module.description,
                                              lessons: module.lessons,
                                              coinReward: module.coinReward,
                                              studyMaterials: next,
                                              quizQuestions: module.quizQuestions,
                                            );
                                          });
                                        },
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save Materials'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizEditorBottomSheet extends StatefulWidget {
  const _QuizEditorBottomSheet({required this.course});

  final Course course;

  @override
  State<_QuizEditorBottomSheet> createState() => _QuizEditorBottomSheetState();
}

class _QuizEditorBottomSheetState extends State<_QuizEditorBottomSheet> {
  late List<_EditableModule> _modules;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _modules = widget.course.modules.map((m) => _EditableModule.fromCourseModule(m)).toList(growable: true);
  }

  int get _totalQuestions => _modules.fold(0, (sum, m) => sum + m.quizQuestions.length);

  int get _minimumRequiredQuestions {
    return 20;
  }

  Future<void> _addQuestion(int moduleIndex) async {
    final question = TextEditingController();
    final optionA = TextEditingController();
    final optionB = TextEditingController();
    final optionC = TextEditingController();
    final optionD = TextEditingController();
    String correctAnswer = 'A';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add Quiz Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: question, decoration: const InputDecoration(labelText: 'Question')),
                const SizedBox(height: 8),
                TextField(controller: optionA, decoration: const InputDecoration(labelText: 'Option A')),
                const SizedBox(height: 8),
                TextField(controller: optionB, decoration: const InputDecoration(labelText: 'Option B')),
                const SizedBox(height: 8),
                TextField(controller: optionC, decoration: const InputDecoration(labelText: 'Option C')),
                const SizedBox(height: 8),
                TextField(controller: optionD, decoration: const InputDecoration(labelText: 'Option D')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: correctAnswer,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Correct: Option A')),
                    DropdownMenuItem(value: 'B', child: Text('Correct: Option B')),
                    DropdownMenuItem(value: 'C', child: Text('Correct: Option C')),
                    DropdownMenuItem(value: 'D', child: Text('Correct: Option D')),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocal(() => correctAnswer = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final q = _QuizQuestionDraft(
        question: question.text.trim(),
        optionA: optionA.text.trim(),
        optionB: optionB.text.trim(),
        optionC: optionC.text.trim(),
        optionD: optionD.text.trim(),
        correctAnswer: correctAnswer,
      );
      if (q.question.isNotEmpty && q.optionA.isNotEmpty && q.optionB.isNotEmpty && q.optionC.isNotEmpty && q.optionD.isNotEmpty) {
        setState(() {
          final module = _modules[moduleIndex];
          final nextQuestions = List<_QuizQuestionDraft>.from(module.quizQuestions)..add(q);
          _modules[moduleIndex] = _EditableModule(
            id: module.id,
            orderIndex: module.orderIndex,
            title: module.title,
            description: module.description,
            lessons: module.lessons,
            coinReward: module.coinReward,
            studyMaterials: module.studyMaterials,
            quizQuestions: nextQuestions,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    final minimum = _minimumRequiredQuestions;
    if (_totalQuestions < minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add at least $minimum questions for ${_modules.length} modules.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.instance.updateCourseDetails(
        widget.course.id,
        title: widget.course.title,
        description: widget.course.description,
        category: widget.course.category,
        duration: widget.course.duration,
        moduleType: widget.course.moduleType,
        instructorName: widget.course.instructorName,
        thumbnailUrl: widget.course.thumbnailUrl,
        difficulty: widget.course.difficulty.name,
        rating: widget.course.rating,
        price: widget.course.price,
        modules: _modules.map((m) => m.toJson(courseId: widget.course.id)).toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save quiz: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Quiz', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Minimum required: $_minimumRequiredQuestions questions for ${_modules.length} modules',
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _modules.isEmpty
                    ? Center(
                        child: Text(
                          'Add modules first to create quiz questions.',
                          style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _modules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final module = _modules[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Module ${module.orderIndex}: ${module.title}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _addQuestion(index),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${module.quizQuestions.length} question(s)',
                                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                                ...module.quizQuestions.asMap().entries.map((entry) {
                                  final qIndex = entry.key;
                                  final q = entry.value;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    leading: const Icon(Icons.help_outline, size: 18),
                                    title: Text(
                                      q.question,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text('Correct: ${q.correctAnswer}', style: GoogleFonts.poppins(fontSize: 11)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          final nextQuestions = List<_QuizQuestionDraft>.from(module.quizQuestions)..removeAt(qIndex);
                                          _modules[index] = _EditableModule(
                                            id: module.id,
                                            orderIndex: module.orderIndex,
                                            title: module.title,
                                            description: module.description,
                                            lessons: module.lessons,
                                            coinReward: module.coinReward,
                                            studyMaterials: module.studyMaterials,
                                            quizQuestions: nextQuestions,
                                          );
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: Text('Save Quiz ($_totalQuestions)'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewCourseBottomSheet extends StatelessWidget {
  final Course course;
  const _ViewCourseBottomSheet({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Description: ${course.description}',
            style: GoogleFonts.poppins(),
          ),
          const SizedBox(height: 16),
          Text(
            'Modules:',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: course.modules.isEmpty ? 1 : course.modules.length,
              itemBuilder: (context, index) {
                if (course.modules.isEmpty)
                  return const Text('No modules available.');
                return ListTile(
                  leading: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.blue,
                  ),
                  title: Text(course.modules[index].title),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
