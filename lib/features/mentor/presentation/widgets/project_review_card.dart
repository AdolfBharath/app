import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/mentor_provider.dart';
import '../../../../config/theme.dart';

class ProjectReviewCard extends StatelessWidget {
  const ProjectReviewCard({super.key, required this.project, this.onTap});

  final MentorProject project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    switch (project.status.toLowerCase()) {
      case 'reviewed':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Reviewed';
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Pending';
        break;
      case 'submitted':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Submitted';
        break;
      case 'validated':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Validated';
        break;
      case 'in_review':
      case 'inreview':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'In Review';
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
        statusLabel = project.status;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: LmsAdminTheme.adminCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      project.studentName.isNotEmpty
                          ? project.studentName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.studentName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (project.isTask)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                              ),
                              child: Text(
                                'TASK',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              project.title,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
