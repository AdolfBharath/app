import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/student_provider.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({super.key});

  double _mockProgress(int index) {
    final raw = 0.3 + index * 0.2;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Progress',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Consumer<StudentProvider>(
          builder: (context, student, _) {
            final courses = student.enrolledCourses;
            if (courses.isEmpty) {
              return Center(
                child: Text(
                  'Enroll in a course to start tracking progress.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: scheme.onSurface.withAlpha(235),
                  ),
                ),
              );
            }

            final progresses = List.generate(
              courses.length,
              (index) => _mockProgress(index),
            );
            final overall = progresses.isEmpty
                ? 0.0
                : progresses.reduce((a, b) => a + b) / progresses.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: overall,
                              strokeWidth: 10,
                              backgroundColor:
                                  scheme.onSurface.withAlpha(12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                            ),
                            Center(
                              child: Text(
                                '${(overall * 100).round()}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Overall progress',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: scheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Enrolled courses', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: courses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final progress = progresses[index];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        color: scheme.surface,
                        shadowColor: theme.shadowColor.withAlpha(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor:
                                      scheme.onSurface.withAlpha(12),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(progress * 100).round()}% completed',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: scheme.onSurface
                                          .withAlpha(150),
                                    ),
                                  ),
                                  Text(
                                    progress >= 1.0
                                        ? 'Completed'
                                        : 'In progress',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: progress >= 1.0
                                          ? scheme.tertiary
                                          : scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
