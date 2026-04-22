import 'package:flutter/material.dart';

class CourseStatusBadge extends StatelessWidget {
  final bool isActive;
  final bool isUnderReview;

  const CourseStatusBadge({
    super.key,
    this.isActive = true,
    this.isUnderReview = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    if (isUnderReview) {
      backgroundColor = const Color(0xFFFEF3C7); // Light yellow
      textColor = const Color(0xFFF59E0B); // Amber
      label = 'In Review';
      icon = Icons.pending_outlined;
    } else if (isActive) {
      backgroundColor = const Color(0xFFD1FAE5); // Light green
      textColor = const Color(0xFF10B981); // Green
      label = 'Active';
      icon = Icons.check_circle_outline;
    } else {
      backgroundColor = const Color(0xFFE5E7EB); // Light gray
      textColor = const Color(0xFF6B7280); // Gray
      label = 'Inactive';
      icon = Icons.pause_circle_outline;
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
