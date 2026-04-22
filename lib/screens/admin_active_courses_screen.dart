import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';

class AdminActiveCoursesScreen extends StatelessWidget {
  const AdminActiveCoursesScreen({super.key});

  static const routeName = '/admin/active-courses';

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseProvider>().courses;
    final auth = context.watch<AuthProvider>();

    // For demonstration: courses tagged isMyCourse are "In Review" (mentor-tagged)
    final activeCourses = courses.where((c) => !c.isMyCourse).toList();
    final reviewCourses = courses.where((c) => c.isMyCourse).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF5F7FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Active Library',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: courses.isEmpty
          ? _EmptyState(
              icon: Icons.menu_book_rounded,
              message: 'No courses found.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${activeCourses.length} Live',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${reviewCourses.length} Under Review',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (activeCourses.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Active Courses',
                    count: activeCourses.length,
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                  const SizedBox(height: 12),
                  ...activeCourses.map(
                    (c) => _CourseCard(course: c, auth: auth, isReview: false),
                  ),
                ],
                if (reviewCourses.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Under Review',
                    count: reviewCourses.length,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                  const SizedBox(height: 12),
                  ...reviewCourses.map(
                    (c) => _CourseCard(course: c, auth: auth, isReview: true),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  final String title;
  final int count;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.auth,
    required this.isReview,
  });

  final Course course;
  final AuthProvider auth;
  final bool isReview;

  @override
  Widget build(BuildContext context) {
    // Find mentor by matching instructor name
    final mentor = auth.mentors
        .where((m) => m.name == course.instructorName)
        .firstOrNull;
    final mentorName = mentor?.name ?? course.instructorName;

    // Student count: students whose batchId matches a batch with this course
    // (approximation — real count would need batch-student join)
    final statusLabel = isReview ? '🟡 In Review' : '✅ Active';
    final statusColor = isReview
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFDCFCE7);
    final statusTextColor = isReview
        ? const Color(0xFFD97706)
        : const Color(0xFF16A34A);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by $mentorName',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              course.description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MetaChip(
                  icon: Icons.star_rounded,
                  label: course.rating.toStringAsFixed(1),
                  iconColor: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _MetaChip(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: course.difficulty.name,
                  iconColor: const Color(0xFF3B82F6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
