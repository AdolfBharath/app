import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../services/api_service.dart';
import 'lesson_player_screen.dart';
import 'login_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  static const routeName = '/course-detail';

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _expandedDescription = false;

  String? _convertDriveToPreviewLink(String rawLink) {
    final trimmed = rawLink.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (!host.contains('drive.google.com')) {
      return trimmed;
    }

    final segments = uri.pathSegments;
    final fileIndex = segments.indexOf('file');
    if (fileIndex >= 0 && fileIndex + 2 < segments.length && segments[fileIndex + 1] == 'd') {
      final fileId = segments[fileIndex + 2];
      return 'https://drive.google.com/file/d/$fileId/preview';
    }

    final id = uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      return 'https://drive.google.com/file/d/$id/preview';
    }

    return trimmed;
  }

  Future<void> _openLessonPlayer({
    required Course course,
    required CourseModule lesson,
    required bool isEnrolled,
  }) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(LoginScreen.routeName);
      return;
    }

    if (auth.currentRole != UserRole.student || !isEnrolled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only enrolled students can access lesson videos.')),
      );
      return;
    }

    final previewLink = _convertDriveToPreviewLink(lesson.videoDriveLink);
    if (previewLink == null || previewLink.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not available for this lesson.')),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonPlayerScreen(
          lessonTitle: lesson.lessonTitle.isNotEmpty ? lesson.lessonTitle : lesson.title,
          videoUrl: previewLink,
          transcript: lesson.transcript,
          description: lesson.moduleDescription.isNotEmpty ? lesson.moduleDescription : lesson.description,
        ),
      ),
    );
  }

  Future<void> _handleEnroll(Course course) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(LoginScreen.routeName);
      return;
    }

    if (auth.currentRole != UserRole.student) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only students can enroll from here.')),
      );
      return;
    }

    try {
      await ApiService.instance.enrollInCourse(course.id);
      await auth.refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled in ${course.title}')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enroll failed: $e')),
      );
    }
  }

  List<_CourseModuleGroup> _groupModules(Course course) {
    final sorted = [...course.modules]
      ..sort((a, b) {
        final byModule = a.moduleNumber.compareTo(b.moduleNumber);
        if (byModule != 0) return byModule;
        return a.order.compareTo(b.order);
      });

    final map = <int, List<CourseModule>>{};
    for (final lesson in sorted) {
      final key = lesson.moduleNumber <= 0 ? 1 : lesson.moduleNumber;
      map.putIfAbsent(key, () => <CourseModule>[]).add(lesson);
    }

    return map.entries
        .map((entry) {
          final lessons = entry.value;
          final first = lessons.first;
          return _CourseModuleGroup(
            moduleNumber: entry.key,
            moduleTitle: first.title,
            moduleDescription: first.moduleDescription.isNotEmpty ? first.moduleDescription : first.description,
            lessons: lessons,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => a.moduleNumber.compareTo(b.moduleNumber));
  }

  @override
  Widget build(BuildContext context) {
    final courseId = ModalRoute.of(context)?.settings.arguments as String?;
    final course = Provider.of<CourseProvider>(
      context,
      listen: false,
    ).getById(courseId ?? '');

    if (course == null) {
      return const Scaffold(body: Center(child: Text('Course not found')));
    }

    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final groupedModules = _groupModules(course);
    final isStudent = auth.currentRole == UserRole.student;
    final isEnrolled = auth.currentUser?.courseIds.contains(course.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Image.asset(
            'assets/logo.png',
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text('Jenovate'),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: course.thumbnailUrl.isNotEmpty
                          ? Image.network(course.thumbnailUrl, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.image_outlined, size: 40),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  course.title,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0ECFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  course.duration.isEmpty ? 'N/A' : course.duration,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _expandedDescription || course.description.length <= 140
                                ? course.description
                                : '${course.description.substring(0, 140)}...',
                            style: textTheme.bodyMedium,
                          ),
                          if (course.description.length > 140)
                            TextButton(
                              onPressed: () {
                                setState(() => _expandedDescription = !_expandedDescription);
                              },
                              child: Text(_expandedDescription ? 'Show less' : 'Read more'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Modules',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${groupedModules.length}',
                    style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (groupedModules.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No modules available'),
                ))
              else
                ...groupedModules.map((moduleGroup) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: Text(
                        'Module ${moduleGroup.moduleNumber}: ${moduleGroup.moduleTitle}',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: moduleGroup.moduleDescription.isNotEmpty
                          ? Text(
                              moduleGroup.moduleDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            )
                          : null,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            children: moduleGroup.lessons.asMap().entries.map((entry) {
                              final index = entry.key;
                              final lesson = entry.value;
                              final hasVideo = lesson.videoDriveLink.trim().isNotEmpty;
                              final canPlay = hasVideo && isStudent && isEnrolled;
                              final lessonTitle = lesson.lessonTitle.isNotEmpty
                                  ? lesson.lessonTitle
                                  : lesson.title;
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lessonTitle,
                                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            lesson.duration.isEmpty ? 'Duration not specified' : lesson.duration,
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: canPlay
                                          ? () => _openLessonPlayer(
                                                course: course,
                                                lesson: lesson,
                                                isEnrolled: isEnrolled,
                                              )
                                          : null,
                                      icon: Icon(
                                        canPlay ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded,
                                        size: 28,
                                        color: canPlay ? theme.colorScheme.primary : const Color(0xFF94A3B8),
                                      ),
                                      tooltip: canPlay
                                          ? 'Play lesson'
                                          : hasVideo
                                              ? 'Enroll to access lesson'
                                              : 'Video unavailable',
                                    ),
                                  ],
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!auth.isLoggedIn || (isStudent && !isEnrolled))
                  ? () => _handleEnroll(course)
                  : null,
              child: Text(
                !auth.isLoggedIn
                    ? 'Login to Enroll'
                    : isStudent
                        ? (isEnrolled ? 'Enrolled' : 'Enroll Now')
                        : 'Students Only',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseModuleGroup {
  _CourseModuleGroup({
    required this.moduleNumber,
    required this.moduleTitle,
    required this.moduleDescription,
    required this.lessons,
  });

  final int moduleNumber;
  final String moduleTitle;
  final String moduleDescription;
  final List<CourseModule> lessons;
}


