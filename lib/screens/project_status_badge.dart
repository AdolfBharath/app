import 'package:flutter/material.dart';
import '../models/project.dart';

class ProjectStatusBadge extends StatelessWidget {
  final ProjectStatus status;

  const ProjectStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case ProjectStatus.reviewed:
        backgroundColor = const Color(0xFFD1FAE5); // Light green
        textColor = const Color(0xFF10B981); // Green
        label = 'Reviewed';
        icon = Icons.check_circle;
        break;
      case ProjectStatus.inReview:
        backgroundColor = const Color(0xFFDBEAFE); // Light blue
        textColor = const Color(0xFF3B82F6); // Blue
        label = 'In Review';
        icon = Icons.rate_review_outlined;
        break;
      case ProjectStatus.rejected:
        backgroundColor = const Color(0xFFFEE2E2); // Light red
        textColor = const Color(0xFFEF4444); // Red
        label = 'Rejected';
        icon = Icons.cancel_outlined;
        break;
      case ProjectStatus.pending:
      default:
        backgroundColor = const Color(0xFFFEF3C7); // Light yellow
        textColor = const Color(0xFFF59E0B); // Amber
        label = 'Pending';
        icon = Icons.pending_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
