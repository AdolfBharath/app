import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../features/student/presentation/providers/student_provider.dart';
import '../services/api_service.dart';
import 'lesson_player_screen.dart';
import 'login_screen.dart';
import '../features/student/presentation/widgets/ask_question_modal.dart';
import '../config/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  static const routeName = '/course-detail';

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _expandedDescription = false;
  bool _quizStarted = false;
  bool _quizSubmitted = false;
  int _quizIndex = 0;
  int _quizScore = 0;
  bool _progressLoading = false;
  String? _loadedProgressCourseId;
  List<CourseQuizQuestion> _selectedQuizQuestions = const [];
  final Map<int, String> _selectedAnswers = <int, String>{};
  Set<String> _completedLessonKeys = <String>{};
  Set<int> _completedModules = <int>{};
  Set<int> _rewardedModules = <int>{};
  bool _quizCompleted = false;
  bool _isRedirecting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRedirecting) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      _isRedirecting = true;
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        }
      });
    }
  }

  bool _isDriveLink(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return false;
    return uri.host.toLowerCase().contains('drive.google.com');
  }

  bool _canAccessLearningContent({
    required AuthProvider auth,
    required bool isEnrolled,
  }) {
    final role = auth.currentRole;
    if (role == UserRole.admin) return true;
    if (role == UserRole.mentor) return true;
    if (role == UserRole.student && isEnrolled) return true;
    return false;
  }

  List<CourseQuizQuestion> _allQuizQuestions(Course course) {
    return course.modules
        .expand((m) => m.quizQuestions)
        .where((q) => q.question.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _startQuizAttempt(Course course) {
    final all = _allQuizQuestions(course).toList(growable: true);
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quiz questions available yet.')),
      );
      return;
    }

    all.shuffle();
    final selected = all.take(all.length >= 7 ? 7 : all.length).toList(growable: false);
    setState(() {
      _selectedQuizQuestions = selected;
      _selectedAnswers.clear();
      _quizStarted = true;
      _quizSubmitted = false;
      _quizIndex = 0;
      _quizScore = 0;
    });
  }

  String _lessonKey(CourseModule module, CourseLesson lesson) {
    return '${module.orderIndex}:${lesson.title.trim()}';
  }

  Future<void> _loadProgress(String courseId) async {
    setState(() => _progressLoading = true);
    try {
      final progress = await ApiService.instance.getCourseProgress(courseId);
      if (!mounted) return;
      setState(() {
        _completedLessonKeys = ((progress['completed_lessons'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        _completedModules = ((progress['completed_modules'] as List?) ?? const [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toSet();
        _rewardedModules = ((progress['rewarded_modules'] as List?) ?? const [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toSet();
        _quizCompleted = progress['quiz_completed'] == true;
      });
    } catch (_) {
      // Keep screen usable even if progress fetch fails.
    } finally {
      if (mounted) setState(() => _progressLoading = false);
    }
  }

  Future<void> _markLessonCompleted({
    required Course course,
    required CourseModule module,
    required CourseLesson lesson,
  }) async {
    final lessonKey = _lessonKey(module, lesson);
    if (_completedLessonKeys.contains(lessonKey)) {
      return;
    }

    try {
      final result = await ApiService.instance.completeLesson(
        courseId: course.id,
        moduleNumber: module.orderIndex,
        lessonKey: lessonKey,
      );

      final completedLessons = ((result['completed_lessons'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      final completedModules = ((result['completed_modules'] as List?) ?? const [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toSet();
      final rewardedModules = ((result['rewarded_modules'] as List?) ?? const [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toSet();
      final rewardGranted = (result['reward_granted'] as num?)?.toInt() ?? 0;
      final coins = (result['coins'] as num?)?.toInt();
      final moduleCompletedNow = result['module_completed_now'] == true;

      if (!mounted) return;

      setState(() {
        _completedLessonKeys = completedLessons;
        _completedModules = completedModules;
        _rewardedModules = rewardedModules;
      });

      if (coins != null) {
        await context.read<StudentProvider>().setCoins(coins);
      }

      if (moduleCompletedNow && rewardGranted > 0 && mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Module Completed!'),
            content: Text('+$rewardGranted Coins Earned'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // Skip hard failure for completion tracking; user can continue learning.
    }
  }

  Future<void> _submitQuiz({required Course course, required bool shouldReward}) async {
    var score = 0;
    for (var i = 0; i < _selectedQuizQuestions.length; i++) {
      final selected = _selectedAnswers[i];
      final answer = _selectedQuizQuestions[i].correctAnswer.toUpperCase();
      if (selected != null && selected.toUpperCase() == answer) {
        score += 1;
      }
    }

    setState(() {
      _quizScore = score;
      _quizSubmitted = true;
    });

    if (!shouldReward) return;

    try {
      final result = await ApiService.instance.completeQuiz(
        courseId: course.id,
        score: score,
        total: _selectedQuizQuestions.length,
      );

      final rewardGranted = (result['reward_granted'] as num?)?.toInt() ?? 0;
      final coins = (result['coins'] as num?)?.toInt();
      if (coins != null) {
        await context.read<StudentProvider>().setCoins(coins);
      }
      if (!mounted) return;

      setState(() {
        _quizCompleted = true;
      });

      if (rewardGranted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quiz completed! +$rewardGranted coins earned.')),
        );
      }
    } catch (_) {
      // Keep local score UI visible even if reward API fails.
    }
  }

  Future<void> _openMaterialLink(String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid material link.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open material link.')),
      );
    }
  }

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
    required CourseModule module,
    required CourseLesson lesson,
    required bool canAccess,
  }) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(LoginScreen.routeName);
      return;
    }

    if (!canAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only enrolled students, mentor, or admin can access lesson videos.')),
      );
      return;
    }

    final rawVideoLink = lesson.videoDriveLink.trim();
    if (!_isDriveLink(rawVideoLink)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Google Drive video links are supported.')),
      );
      return;
    }

    final previewLink = _convertDriveToPreviewLink(rawVideoLink);
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
          lessonTitle: lesson.title,
          videoUrl: previewLink,
          transcript: lesson.transcript,
          description: module.description,
          courseId: course.id,
          moduleId: module.id,
          lessonId: lesson.id,
          mentorId: course.mentorId ?? '',
          courseTitle: course.title,
          moduleTitle: module.title,
        ),
      ),
    );

    final isStudent = auth.currentRole == UserRole.student;
    final isEnrolled = auth.currentUser?.courseIds.contains(course.id) ?? false;
    if (isStudent && isEnrolled) {
      await _markLessonCompleted(course: course, module: module, lesson: lesson);
    }
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

  // _groupModules is no longer needed with the nested model

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String courseId = '';
    String? targetLessonKey;

    if (args is String) {
      courseId = args;
    } else if (args is Map<String, dynamic>) {
      courseId = args['courseId'] ?? '';
      targetLessonKey = args['targetLessonKey'];
    }

    final course = Provider.of<CourseProvider>(
      context,
      listen: false,
    ).getById(courseId);

    if (course == null) {
      return const Scaffold(body: Center(child: Text('Course not found')));
    }

    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final modules = course.modules;
    final modulesWithMaterials = modules
      .where((m) => m.studyMaterials.isNotEmpty)
      .toList(growable: false);
    final totalQuizQuestions = _allQuizQuestions(course).length;
    final isStudent = auth.currentRole == UserRole.student;
    final isEnrolled = auth.currentUser?.courseIds.contains(course.id) ?? false;
    if (_loadedProgressCourseId != course.id) {
      _loadedProgressCourseId = course.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadProgress(course.id);
      });
    }
    final canAccessLearningContent = _canAccessLearningContent(
      auth: auth,
      isEnrolled: isEnrolled,
    );

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
                      color: Colors.black.withAlpha(10),
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
                    if (isEnrolled)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => AskQuestionModal(
                                  courseId: course.id,
                                  moduleId: 'general',
                                  lessonId: 'general',
                                  mentorId: course.mentorId ?? '',
                                  courseTitle: course.title,
                                  moduleTitle: 'General Course Inquiry',
                                  lessonTitle: 'Course Overview',
                                ),
                              );
                            },
                            icon: const Icon(Icons.help_outline_rounded, size: 18),
                            label: const Text('Ask Question about Course'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LmsAdminTheme.primaryBlue,
                              side: const BorderSide(color: LmsAdminTheme.primaryBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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
                    '${modules.length}',
                    style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              if (_progressLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 10),
              if (modules.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No modules available'),
                ))
              else
                ...modules.map((module) {
                  final moduleLessonKeys = module.lessons
                    .map((lesson) => _lessonKey(module, lesson))
                    .toList(growable: false);
                  final completedCount = moduleLessonKeys
                    .where((key) => _completedLessonKeys.contains(key))
                    .length;
                  final totalCount = module.lessons.length;
                  final progressValue = totalCount == 0 ? 0.0 : completedCount / totalCount;
                  final moduleReward = module.coinReward;
                  final shouldExpand = targetLessonKey != null && moduleLessonKeys.contains(targetLessonKey);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: shouldExpand,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: Text(
                        'Module ${module.orderIndex}: ${module.title}',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: module.description.isNotEmpty
                          ? Text(
                              module.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            )
                          : null,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '$completedCount / $totalCount lessons completed',
                                    style: textTheme.bodySmall,
                                  ),
                                  const Spacer(),
                                  if (moduleReward > 0)
                                    Text(
                                      'Reward: +$moduleReward',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFFB45309),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            children: module.lessons.asMap().entries.map((entry) {
                              final index = entry.key;
                              final lesson = entry.value;
                              final hasVideo = lesson.videoDriveLink.trim().isNotEmpty;
                              final canPlay = hasVideo && canAccessLearningContent;
                              final lessonKey = _lessonKey(module, lesson);
                              final isLessonCompleted = _completedLessonKeys.contains(lessonKey);
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
                                            lesson.title,
                                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            lesson.duration.isEmpty ? 'Duration not specified' : lesson.duration,
                                            style: textTheme.bodySmall,
                                          ),
                                          if (isLessonCompleted)
                                            Text(
                                              'Completed',
                                              style: textTheme.bodySmall?.copyWith(
                                                color: const Color(0xFF16A34A),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: canPlay
                                          ? () => _openLessonPlayer(
                                                course: course,
                                                module: module,
                                                lesson: lesson,
                                                canAccess: canAccessLearningContent,
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
                                            ? 'Access is restricted'
                                              : 'Video unavailable',
                                    ),
                                  ],
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                        if (_completedModules.contains(module.orderIndex))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Completed${_rewardedModules.contains(module.orderIndex) ? ' • Reward Claimed' : ''}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF15803D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Study Materials',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${modulesWithMaterials.fold<int>(0, (sum, m) => sum + m.studyMaterials.length)}',
                    style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (modulesWithMaterials.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No study materials available'),
                  ),
                )
              else if (!canAccessLearningContent)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Only enrolled students, mentor, or admin can access materials.'),
                  ),
                )
              else
                ...modulesWithMaterials.map((module) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      color: const Color(0xFFF8FAFF),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Module ${module.orderIndex}: ${module.title}',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...module.studyMaterials.map((material) {
                          final hasDrive = material.driveLink.trim().isNotEmpty;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: hasDrive ? () => _openMaterialLink(material.driveLink) : null,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(material.title),
                            subtitle: Text(
                              hasDrive ? material.driveLink : 'No Drive link',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              hasDrive ? Icons.open_in_new_rounded : Icons.lock_outline_rounded,
                              color: hasDrive ? theme.colorScheme.primary : const Color(0xFF94A3B8),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Course Quiz',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalQuizQuestions questions',
                    style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!canAccessLearningContent)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Only enrolled students, mentor, or admin can attempt this quiz.'),
                )
              else if (totalQuizQuestions < 20)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Quiz is being prepared. Minimum 20 questions required.', style: textTheme.bodyMedium),
                )
              else if (!_quizStarted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startQuizAttempt(course),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(_quizCompleted
                        ? 'Start New Quiz Attempt (7 Random Questions)'
                        : 'Start Quiz (7 Random Questions)'),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_quizIndex + 1} of ${_selectedQuizQuestions.length}',
                        style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedQuizQuestions[_quizIndex].question,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...[
                        ('A', _selectedQuizQuestions[_quizIndex].optionA),
                        ('B', _selectedQuizQuestions[_quizIndex].optionB),
                        ('C', _selectedQuizQuestions[_quizIndex].optionC),
                        ('D', _selectedQuizQuestions[_quizIndex].optionD),
                      ].map((opt) {
                        final key = opt.$1;
                        final value = opt.$2;
                        return RadioListTile<String>(
                          value: key,
                          groupValue: _selectedAnswers[_quizIndex],
                          onChanged: _quizSubmitted
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _selectedAnswers[_quizIndex] = v;
                                  });
                                },
                          title: Text('$key. $value'),
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _quizIndex > 0 && !_quizSubmitted
                                ? () => setState(() => _quizIndex -= 1)
                                : null,
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 8),
                          if (_quizIndex < _selectedQuizQuestions.length - 1)
                            FilledButton(
                              onPressed: _quizSubmitted
                                  ? null
                                  : () => setState(() => _quizIndex += 1),
                              child: const Text('Next'),
                            )
                          else
                            FilledButton(
                              onPressed: _quizSubmitted
                                  ? null
                                  : () => _submitQuiz(
                                        course: course,
                                        shouldReward: isStudent && isEnrolled,
                                      ),
                              child: const Text('Submit Quiz'),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _startQuizAttempt(course),
                            child: const Text('New Attempt'),
                          ),
                        ],
                      ),
                      if (_quizSubmitted) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Score: $_quizScore / ${_selectedQuizQuestions.length}',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ..._selectedQuizQuestions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final question = entry.value;
                          final chosen = _selectedAnswers[idx] ?? '-';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Q${idx + 1}: Correct ${question.correctAnswer} | Your answer: $chosen',
                              style: textTheme.bodySmall,
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
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
                        ? (isEnrolled 
                            ? 'Enrolled' 
                            : 'Enroll Now - ${course.price == 0 ? 'Free' : '₹${course.price.toStringAsFixed(0)}'}')
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


