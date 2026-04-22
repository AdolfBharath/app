import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course.dart';
import '../shared/index.dart';

/// View dialog for displaying course details
class CourseViewDialog extends StatelessWidget {
  const CourseViewDialog({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        course.title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailItem(label: 'Description', value: course.description),
            DetailItem(label: 'Instructor', value: course.instructorName),
            DetailItem(label: 'Difficulty', value: course.difficulty.name),
            DetailItem(
              label: 'Rating',
              value: course.rating.toStringAsFixed(1),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}
