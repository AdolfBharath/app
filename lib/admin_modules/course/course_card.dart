import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/course.dart';

/// Course card component for displaying a single course in the list
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.onDelete,
    required this.onView,
    required this.onEdit,
    required this.onAssignments,
  });

  final Course course;
  final VoidCallback onDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onAssignments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LmsAdminTheme.adminCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildThumbnail(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.black.withOpacity(0.04)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _iconActionTile(
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF3B82F6),
                  background: const Color(0xFFE8F0FE),
                  onTap: onView,
                ),
                _iconActionTile(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF10B981),
                  background: const Color(0xFFE7F8F2),
                  onTap: onEdit,
                ),
                _iconActionTile(
                  icon: Icons.assignment_turned_in_outlined,
                  color: const Color(0xFF0F766E),
                  background: const Color(0xFFE6FFFA),
                  onTap: onAssignments,
                ),
                _iconActionTile(
                  icon: Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  background: const Color(0xFFFDECEC),
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconActionTile({
    required IconData icon,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 52,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (course.thumbnailUrl.isNotEmpty) {
      return Image.network(
        course.thumbnailUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _placeholderThumbnail();
        },
      );
    }
    return _placeholderThumbnail();
  }

  Widget _placeholderThumbnail() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.menu_book_outlined, color: Color(0xFF9CA3AF)),
    );
  }
}
