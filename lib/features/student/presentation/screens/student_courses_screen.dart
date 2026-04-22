import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../screens/course_detail_screen.dart';
import '../providers/student_nav_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import 'student_notifications_screen.dart';

class StudentCoursesScreen extends StatelessWidget {
  const StudentCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudentHeaderRow(
                      onNotificationsTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentNotificationsScreen(),
                        ),
                      ),
                      onProfileTap: () =>
                          context.read<StudentNavProvider>().setIndex(4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('My Courses',
                                  style: theme.textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                'Keep track of your learning progress',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface.withValues(alpha: 160),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Stats pill
                        Consumer<StudentProvider>(
                          builder: (_, student, __) => _StatsPill(
                            count: student.enrolledCourses.length,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: TabBar(
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: const Color(0xFF2563EB),
                              unselectedLabelColor: const Color(0xFF9CA3AF),
                              indicator: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                              ),
                              labelStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              unselectedLabelStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              tabs: const [
                                Tab(text: 'Ongoing'),
                                Tab(text: 'Completed'),
                                Tab(text: 'Archived'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.format_list_bulleted_rounded, color: const Color(0xFF9CA3AF), size: 24),
                        const SizedBox(width: 8),
                        Icon(Icons.grid_view_rounded, color: const Color(0xFF2563EB), size: 24),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Tab views ────────────────────────────────
              Expanded(
                child: Consumer<StudentProvider>(
                  builder: (context, student, _) {
                    final enrolled = student.enrolledCourses;
                    final ongoing = enrolled.where((c) {
                      final p = _mockProgress(enrolled.indexOf(c));
                      return p > 0.01 && p < 1.0;
                    }).toList();
                    final completed = enrolled.where((c) {
                      final p = _mockProgress(enrolled.indexOf(c));
                      return p >= 1.0;
                    }).toList();

                    return TabBarView(
                      children: [
                        _CoursesList(courses: enrolled),
                        _CoursesList(courses: ongoing),
                        _CoursesList(courses: completed, completed: true),
                      ],
                    );
                  },
                ),
              ),

              // ── Explore banner ───────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _ExploreBanner(
                  onExplore: () =>
                      context.read<StudentNavProvider>().setIndex(0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _mockProgress(int index) =>
      (0.25 + index * 0.25).clamp(0.0, 1.0);
}

// ─── Courses list ─────────────────────────────────────────────────────────────
class _CoursesList extends StatelessWidget {
  const _CoursesList({required this.courses, this.completed = false});

  final List courses;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              completed ? Icons.emoji_events_outlined : Icons.school_outlined,
              size: 48,
              color: scheme.onSurface.withValues(alpha: 80),
            ),
            const SizedBox(height: 12),
            Text(
              'No courses here yet',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 160),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final course = courses[index];
        final progress = StudentCoursesScreen._mockProgress(index);
        return GestureDetector(
          onTap: () => Navigator.of(context)
              .pushNamed(CourseDetailScreen.routeName, arguments: course.id),
          child: _CourseCard(course: course, progress: progress),
        )
            .animate(delay: Duration(milliseconds: index * 60))
            .fadeIn(duration: 280.ms)
            .slideY(begin: 0.06, end: 0);
      },
    );
  }
}

// ─── Course card ──────────────────────────────────────────────────────────────
class _CourseCard extends StatefulWidget {
  const _CourseCard({required this.course, required this.progress});
  final dynamic course;
  final double progress;
  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompleted = widget.progress >= 1.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.98 : 1.0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full bleed Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: widget.course.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            widget.course.thumbnailUrl,
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _Placeholder(
                                size: double.infinity, height: 140, color: const Color(0xFFF3F4F6)),
                          )
                        : _Placeholder(size: double.infinity, height: 140, color: const Color(0xFFF3F4F6)),
                  ),
                  // "Play / Continue" overlay pill
                  Positioned(
                    right: 12,
                    bottom: -16, // overlap bottom edge
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                             isCompleted ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                             color: Colors.white,
                             size: 16
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCompleted ? 'Completed' : 'Continue',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              // Info Bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 14, color: const Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          'Lesson 24/30',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.schedule_outlined,
                            size: 14, color: const Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          '2 hrs 40 mins',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: widget.progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(widget.progress * 100).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
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
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, this.height, required this.color});

  final double size;
  final double? height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: height ?? size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.play_circle_outline_rounded,
          color: color, size: (height ?? size) * 0.45),
    );
  }
}


// ─── Stats pill ───────────────────────────────────────────────────────────────
class _StatsPill extends StatelessWidget {
  const _StatsPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // soft blue background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count Active',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2563EB), // solid blue text
        ),
      ),
    );
  }
}

// ─── Explore banner ───────────────────────────────────────────────────────────
class _ExploreBanner extends StatelessWidget {
  const _ExploreBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 24)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.rocket_launch_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready for more?',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore new courses in your favourite category',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: 160),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onExplore,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text('Explore'),
          ),
        ],
      ),
    );
  }
}
