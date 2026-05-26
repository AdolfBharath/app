import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../providers/config_provider.dart';
import '../features/student/presentation/providers/student_provider.dart';
import '../services/api_service.dart';
import 'lesson_player_screen.dart';
import 'login_screen.dart';
import 'course_quiz_screen.dart';
import 'module_quiz_screen.dart';
import '../features/student/presentation/widgets/ask_question_modal.dart';
import '../config/theme.dart';
import '../utils/course_cta.dart';
import '../widgets/course_cta_button.dart';
import 'package:my_app/utils/ui_utils.dart';

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
  String? _refreshedCourseId;
  List<CourseQuizQuestion> _selectedQuizQuestions = const [];
  final Map<int, String> _selectedAnswers = <int, String>{};
  Set<String> _completedLessonKeys = <String>{};
  Set<int> _completedModules = <int>{};
  Set<int> _rewardedModules = <int>{};
  bool _quizCompleted = false;
  bool _quizLocked = false;
  bool _quizRewatchRequired = false;
  int _quizAttempts = 0;
  int _quizFailedAttempts = 0;
  int _quizBestScore = 0;
  Map<String, dynamic> _moduleQuizStates = <String, dynamic>{};
  bool _isRedirecting = false;
  bool _ctaLoading = false;
  Course? _freshCourse;
  String? _freshCourseId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  bool _isEnrolledInCourse(Course course, AuthProvider auth) {
    if (auth.currentUser?.courseIds.contains(course.id) == true) return true;
    final student = context.read<StudentProvider>();
    return student.enrolledCourses.any((item) => item.id == course.id);
  }

  List<CourseQuizQuestion> _allQuizQuestions(Course course) {
    return course.modules
        .expand((m) => m.quizQuestions)
        .where((q) => q.question.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _moduleQuizKey(CourseModule module) {
    if (module.id.trim().isNotEmpty) return module.id.trim();
    return 'module_${module.orderIndex}';
  }

  Map<String, dynamic> _moduleQuizState(CourseModule module) {
    final raw = _moduleQuizStates[_moduleQuizKey(module)];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  bool _moduleQuizLocked(CourseModule module) {
    final state = _moduleQuizState(module);
    return state['locked'] == true || state['rewatch_required'] == true;
  }

  bool _moduleQuizCompleted(CourseModule module) {
    return _moduleQuizState(module)['completed'] == true;
  }

  bool _isModuleCompleted(CourseModule module) {
    if (_completedModules.contains(module.orderIndex)) return true;
    if (module.lessons.isEmpty) return false;
    return module.lessons.every(
      (lesson) => _completedLessonKeys.contains(_lessonKey(module, lesson)),
    );
  }

  int _moduleQuizBestScore(CourseModule module) {
    return (_moduleQuizState(module)['best_score'] as num?)?.toInt() ?? 0;
  }

  Future<void> _openModuleQuiz({
    required Course course,
    required CourseModule module,
    required bool shouldStoreResult,
  }) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ModuleQuizScreen(
          course: course,
          module: module,
          initialState: _moduleQuizState(module),
          shouldStoreResult: shouldStoreResult,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _moduleQuizStates = _decodeModuleQuizState(result['module_quiz_state']);
      _quizCompleted = result['quiz_completed'] == true;
      _quizLocked = result['quiz_locked'] == true;
      _quizRewatchRequired = result['quiz_rewatch_required'] == true;
      _quizAttempts =
          (result['quiz_attempts'] as num?)?.toInt() ?? _quizAttempts;
      _quizFailedAttempts =
          (result['quiz_failed_attempts'] as num?)?.toInt() ??
          _quizFailedAttempts;
      _quizBestScore =
          (result['quiz_best_score'] as num?)?.toInt() ?? _quizBestScore;
    });
  }

  Future<void> _openCourseQuiz({
    required Course course,
    required bool shouldStoreResult,
  }) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CourseQuizScreen(
          course: course,
          initialState: {
            'completed': _quizCompleted,
            'locked': _quizLocked,
            'rewatch_required': _quizRewatchRequired,
            'attempts': _quizAttempts,
            'failed_attempts': _quizFailedAttempts,
            'best_score': _quizBestScore,
          },
          shouldStoreResult: shouldStoreResult,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _quizCompleted = result['quiz_completed'] == true;
      _quizLocked = result['quiz_locked'] == true;
      _quizRewatchRequired = result['quiz_rewatch_required'] == true;
      _quizAttempts =
          (result['quiz_attempts'] as num?)?.toInt() ?? _quizAttempts;
      _quizFailedAttempts =
          (result['quiz_failed_attempts'] as num?)?.toInt() ??
          _quizFailedAttempts;
      _quizBestScore =
          (result['quiz_best_score'] as num?)?.toInt() ?? _quizBestScore;
    });
  }

  Map<String, dynamic> _decodeModuleQuizState(dynamic raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  void _startQuizAttempt(Course course) {
    final all = _allQuizQuestions(course).toList(growable: true);
    if (!_isFinalQuizUnlocked(course)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete 100% of the course to unlock this quiz.'),
        ),
      );
      return;
    }
    if (all.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 10 quiz questions required.')),
      );
      return;
    }
    if (_quizLocked || _quizRewatchRequired || _quizAttempts >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have used all 5 course quiz attempts.'),
        ),
      );
      return;
    }

    all.shuffle();
    final selected = all.take(10).toList(growable: false);
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
        _completedLessonKeys =
            ((progress['completed_lessons'] as List?) ?? const [])
                .map((e) => e.toString())
                .toSet();
        _completedModules =
            ((progress['completed_modules'] as List?) ?? const [])
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e > 0)
                .toSet();
        _rewardedModules = ((progress['rewarded_modules'] as List?) ?? const [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toSet();
        _quizCompleted = progress['quiz_completed'] == true;
        _quizLocked = progress['quiz_locked'] == true;
        _quizRewatchRequired = progress['quiz_rewatch_required'] == true;
        _quizAttempts = (progress['quiz_attempts'] as num?)?.toInt() ?? 0;
        _quizFailedAttempts =
            (progress['quiz_failed_attempts'] as num?)?.toInt() ?? 0;
        _quizBestScore = (progress['quiz_best_score'] as num?)?.toInt() ?? 0;
        _moduleQuizStates = _decodeModuleQuizState(
          progress['module_quiz_state'],
        );
      });
    } catch (_) {
      // Keep screen usable even if progress fetch fails.
    } finally {
      if (mounted) setState(() => _progressLoading = false);
    }
  }

  Future<void> _loadFreshCourse(String courseId) async {
    final normalized = courseId.trim();
    if (normalized.isEmpty || _freshCourseId == normalized) return;
    _freshCourseId = normalized;
    try {
      final course = await ApiService.instance.getCourseById(normalized);
      if (!mounted) return;
      if (course != null) {
        setState(() => _freshCourse = course);
      }
    } catch (_) {
      // Keep the course provided by the list if the direct fetch fails.
    }
  }

  Future<void> _markLessonCompleted({
    required Course course,
    required CourseModule module,
    required CourseLesson lesson,
    bool showCompletionDialog = true,
  }) async {
    final lessonKey = _lessonKey(module, lesson);
    if (_completedLessonKeys.contains(lessonKey)) {
      return;
    }

    final optimisticLessons = {..._completedLessonKeys, lessonKey};
    final optimisticModuleCompleted =
        module.lessons.isNotEmpty &&
        module.lessons.every(
          (item) => optimisticLessons.contains(_lessonKey(module, item)),
        );
    if (mounted) {
      setState(() {
        _completedLessonKeys = optimisticLessons;
        if (optimisticModuleCompleted) {
          _completedModules = {..._completedModules, module.orderIndex};
        }
      });
    }

    try {
      final result = await ApiService.instance.completeLesson(
        courseId: course.id,
        moduleNumber: module.orderIndex,
        lessonKey: lessonKey,
        moduleLessonKeys: module.lessons
            .map((item) => _lessonKey(module, item))
            .toList(growable: false),
        totalLessonCount: course.modules.fold<int>(
          0,
          (sum, item) => sum + item.lessons.length,
        ),
      );

      final completedLessons =
          ((result['completed_lessons'] as List?) ?? const [])
              .map((e) => e.toString())
              .toSet();
      final completedModules =
          ((result['completed_modules'] as List?) ?? const [])
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toSet();
      final rewardedModules =
          ((result['rewarded_modules'] as List?) ?? const [])
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toSet();
      final rewardGranted = (result['reward_granted'] as num?)?.toInt() ?? 0;
      final coins = (result['coins'] as num?)?.toInt();
      final moduleCompletedNow = result['module_completed_now'] == true;
      final moduleLessonsCompleted =
          module.lessons.isNotEmpty &&
          module.lessons.every(
            (item) => completedLessons.contains(_lessonKey(module, item)),
          );

      if (!mounted) return;
      final studentProvider = context.read<StudentProvider>();

      setState(() {
        _completedLessonKeys = completedLessons;
        _completedModules = {
          ...completedModules,
          if (moduleLessonsCompleted) module.orderIndex,
        };
        _rewardedModules = rewardedModules;
      });

      if (coins != null) {
        await studentProvider.setCoins(coins);
      }
      await studentProvider.fetchProgress(course.id);

      if (showCompletionDialog &&
          moduleCompletedNow &&
          rewardGranted > 0 &&
          mounted) {
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
    } catch (e) {
      if (!mounted) return;
      showTopNotification(context, 'Could not save lesson progress: $e');
    }
  }

  Future<void> _submitQuiz({
    required Course course,
    required bool shouldReward,
  }) async {
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

    final studentProvider = context.read<StudentProvider>();
    try {
      final passScore = course.quizPassScore > 0 ? course.quizPassScore : 9;
      final result = await ApiService.instance.completeQuiz(
        courseId: course.id,
        score: score,
        total: _selectedQuizQuestions.length,
        passScore: passScore,
      );

      final rewardGranted = (result['reward_granted'] as num?)?.toInt() ?? 0;
      final coins = (result['coins'] as num?)?.toInt();
      if (coins != null) {
        await studentProvider.setCoins(coins);
      }
      if (!mounted) return;

      setState(() {
        _quizCompleted = result['quiz_completed'] == true;
        _quizLocked = result['quiz_locked'] == true;
        _quizRewatchRequired = result['quiz_rewatch_required'] == true;
        _quizAttempts =
            (result['quiz_attempts'] as num?)?.toInt() ?? _quizAttempts;
        _quizFailedAttempts =
            (result['quiz_failed_attempts'] as num?)?.toInt() ??
            _quizFailedAttempts;
        _quizBestScore =
            (result['quiz_best_score'] as num?)?.toInt() ?? _quizBestScore;
      });

      if (rewardGranted > 0) {
        showTopNotification(
          context,
          'Quiz completed! +$rewardGranted coins earned.',
        );
      } else if (_quizLocked) {
        showTopNotification(
          context,
          'Quiz locked after 3 failed attempts. Rewatch a module lesson to retry.',
        );
      }
    } catch (e) {
      showTopNotification(context, 'Failed to update progress: $e');
    }
  }

  Future<void> _openMaterialLink(String? link) async {
    if (link == null) return;
    final uri = Uri.tryParse(link);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid material link.')));
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
    if (fileIndex >= 0 &&
        fileIndex + 2 < segments.length &&
        segments[fileIndex + 1] == 'd') {
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
        const SnackBar(
          content: Text(
            'Only enrolled students, mentor, or admin can access lesson videos.',
          ),
        ),
      );
      return;
    }

    final rawVideoLink = lesson.videoDriveLink.trim();
    if (!_isDriveLink(rawVideoLink)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Google Drive video links are supported.'),
        ),
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

    final isStudent = auth.currentRole == UserRole.student;
    final isEnrolled = _isEnrolledInCourse(course, auth);
    if (isStudent && isEnrolled) {
      unawaited(_markLessonCompleted(
        course: course,
        module: module,
        lesson: lesson,
        showCompletionDialog: false,
      ));
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

    if (isStudent && isEnrolled) {
      if (_moduleQuizLocked(module) || _quizLocked || _quizRewatchRequired) {
        try {
          final result = await ApiService.instance.unlockQuizAfterRewatch(
            courseId: course.id,
            moduleId: module.id,
            moduleOrder: module.orderIndex,
          );
          if (mounted) {
            setState(() {
              _moduleQuizStates = _decodeModuleQuizState(
                result['module_quiz_state'],
              );
              _quizLocked = result['quiz_locked'] == true;
              _quizRewatchRequired = result['quiz_rewatch_required'] == true;
              _quizFailedAttempts =
                  (result['quiz_failed_attempts'] as num?)?.toInt() ?? 0;
            });
            showTopNotification(
              context,
              'Quiz unlocked. You can retake it now.',
            );
          }
        } catch (_) {}
      }
      await _markLessonCompleted(
        course: course,
        module: module,
        lesson: lesson,
      );
    }
  }

  double _calculateCourseProgress(Course course) {
    var total = 0;
    var completed = 0;
    for (final module in course.modules) {
      for (final lesson in module.lessons) {
        total += 1;
        final key = _lessonKey(module, lesson);
        if (_completedLessonKeys.contains(key)) {
          completed += 1;
        }
      }
      if (module.quizQuestions.isNotEmpty) {
        total += 1;
        if (_moduleQuizCompleted(module)) completed += 1;
      }
    }
    if (total == 0) return 0.0;
    return (completed / total).clamp(0.0, 1.0);
  }

  double _calculateLessonProgress(Course course) {
    var total = 0;
    var completed = 0;
    for (final module in course.modules) {
      for (final lesson in module.lessons) {
        total += 1;
        if (_completedLessonKeys.contains(_lessonKey(module, lesson))) {
          completed += 1;
        }
      }
    }
    if (total == 0) return 0.0;
    return (completed / total).clamp(0.0, 1.0);
  }

  bool _hasAnyLessons(Course course) {
    return course.modules.any((module) => module.lessons.isNotEmpty);
  }

  bool _isFinalQuizUnlocked(Course course) {
    final hasLessons = _hasAnyLessons(course);
    if (hasLessons && _calculateLessonProgress(course) >= 1.0) {
      return true;
    }
    if (!hasLessons && _allQuizQuestions(course).isNotEmpty) {
      return true;
    }
    final modulesWithLessons = course.modules.where(
      (module) => module.lessons.isNotEmpty,
    );
    return modulesWithLessons.isNotEmpty && modulesWithLessons.every(
      (module) =>
          _completedModules.contains(module.orderIndex) ||
          module.lessons.every(
            (lesson) =>
                _completedLessonKeys.contains(_lessonKey(module, lesson)),
          ),
    );
  }

  ({CourseModule? module, CourseLesson? lesson}) _nextLessonFor(Course course) {
    for (final module in course.modules) {
      for (final lesson in module.lessons) {
        final key = _lessonKey(module, lesson);
        if (!_completedLessonKeys.contains(key)) {
          return (module: module, lesson: lesson);
        }
      }
    }
    if (course.modules.isNotEmpty && course.modules.first.lessons.isNotEmpty) {
      return (
        module: course.modules.first,
        lesson: course.modules.first.lessons.first,
      );
    }
    return (module: null, lesson: null);
  }

  Future<void> _openJenovateWebsite() async {
    final uri = Uri.parse('https://jenovate.in/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleEnroll(Course course) async {
    final auth = context.read<AuthProvider>();
    final student = context.read<StudentProvider>();
    if (course.price > 0) {
      final formUrl = course.googleFormUrl.trim();
      if (formUrl.isEmpty) {
        if (!mounted) return;
        showTopNotification(context, 'Purchase form is not configured.');
        return;
      }
      final uri = Uri.tryParse(formUrl);
      if (uri == null || !uri.hasScheme) {
        if (!mounted) return;
        showTopNotification(context, 'Invalid purchase form link.');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

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

    final costCoins = course.price.round();
    if (costCoins > 0) {
      final ok = await student.spendCoins(costCoins);
      if (!ok) {
        if (!mounted) return;
        showTopNotification(context, 'Not enough coins. Need $costCoins.');
        return;
      }
    }

    try {
      setState(() => _ctaLoading = true);
      await ApiService.instance.enrollInCourse(course.id);
      await auth.refreshCurrentUser();
      if (!mounted) return;
      showTopNotification(context, 'Enrolled in ${course.title}!');
    } catch (e) {
      if (!mounted) return;
      showTopNotification(context, 'Enrollment failed: $e');
    } finally {
      if (mounted) setState(() => _ctaLoading = false);
    }
  }

  void _handleCtaAction({
    required Course course,
    required CourseCta cta,
    required bool canAccess,
    required bool isEnrolled,
  }) {
    if (cta.state == CourseCtaState.buy) {
      _openJenovateWebsite();
    } else if (cta.state == CourseCtaState.login) {
      Navigator.of(context).pushNamed(LoginScreen.routeName);
    } else if (cta.state == CourseCtaState.enroll) {
      _handleEnroll(course);
    } else if (cta.state == CourseCtaState.continueLearning ||
        cta.state == CourseCtaState.start) {
      final next = _nextLessonFor(course);
      if (next.module != null && next.lesson != null) {
        _openLessonPlayer(
          course: course,
          module: next.module!,
          lesson: next.lesson!,
          canAccess: canAccess,
        );
      }
    } else if (cta.state == CourseCtaState.review) {
      final url = context.read<ConfigProvider>().courseReviewFormUrl.trim();
      if (url.isEmpty) {
        showTopNotification(context, 'Course review form is not configured.');
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null) {
        showTopNotification(context, 'Invalid course review form link.');
        return;
      }
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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

    final auth = context.watch<AuthProvider>();
    final studentProvider = context.watch<StudentProvider>();
    if (courseId.isNotEmpty && _refreshedCourseId != courseId) {
      _refreshedCourseId = courseId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadFreshCourse(courseId);
        final assignedCourseIds =
            context.read<AuthProvider>().currentUser?.courseIds ??
            const <String>[];
        context.read<StudentProvider>().fetchCourses(
          assignedCourseIds: assignedCourseIds,
        );
      });
    }

    Course? findStudentCourse() {
      for (final course in [
        ...studentProvider.enrolledCourses,
        ...studentProvider.allCourses,
      ]) {
        if (course.id == courseId) return course;
      }
      return null;
    }

    final course = (_freshCourse?.id == courseId ? _freshCourse : null) ??
        findStudentCourse() ??
        Provider.of<CourseProvider>(context, listen: false).getById(courseId);

    if (course == null) {
      return const Scaffold(body: Center(child: Text('Course not found')));
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final modules = course.modules;
    final modulesWithMaterials = modules
        .where((m) => m.studyMaterials.isNotEmpty)
        .toList(growable: false);
    final totalQuizQuestions = _allQuizQuestions(course).length;
    final isStudent = auth.currentRole == UserRole.student;
    final isEnrolled =
        (auth.currentUser?.courseIds.contains(course.id) ?? false) ||
        studentProvider.enrolledCourses.any((item) => item.id == course.id);
    final progressRatio = _calculateCourseProgress(course);
    final cta = isStudent
        ? resolveCourseCta(
            isLoggedIn: auth.isLoggedIn,
            isStudent: true,
            isEnrolled: isEnrolled,
            price: course.price,
            progress: progressRatio,
          )
        : const CourseCta(CourseCtaState.review, 'Open Course');
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
            errorBuilder: (context, error, stackTrace) =>
                const Text('Jenovate'),
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
                          ? CachedNetworkImage(
                              imageUrl: course.thumbnailUrl,
                              fit: BoxFit.cover,
                            )
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0ECFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  course.duration.isEmpty
                                      ? 'N/A'
                                      : course.duration,
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
                            _expandedDescription ||
                                    course.description.length <= 140
                                ? course.description
                                : '${course.description.substring(0, 140)}...',
                            style: textTheme.bodyMedium,
                          ),
                          if (course.description.length > 140)
                            TextButton(
                              onPressed: () {
                                setState(
                                  () => _expandedDescription =
                                      !_expandedDescription,
                                );
                              },
                              child: Text(
                                _expandedDescription
                                    ? 'Show less'
                                    : 'Read more',
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isEnrolled)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Ask Question about Course'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LmsAdminTheme.primaryBlue,
                              side: const BorderSide(
                                color: LmsAdminTheme.primaryBlue,
                              ),
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
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${modules.length}',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
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
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No modules available'),
                  ),
                )
              else
                ...modules.map((module) {
                  final moduleLessonKeys = module.lessons
                      .map((lesson) => _lessonKey(module, lesson))
                      .toList(growable: false);
                  final completedCount = moduleLessonKeys
                      .where((key) => _completedLessonKeys.contains(key))
                      .length;
                  final totalCount = module.lessons.length;
                  final progressValue = totalCount == 0
                      ? 0.0
                      : completedCount / totalCount;
                  final moduleReward = module.coinReward;
                  final shouldExpand =
                      targetLessonKey != null &&
                      moduleLessonKeys.contains(targetLessonKey);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(70),
                      ),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: shouldExpand,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      title: Text(
                        'Module ${module.orderIndex}: ${module.title}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                            children: module.lessons
                                .asMap()
                                .entries
                                .map((entry) {
                                  final index = entry.key;
                                  final lesson = entry.value;
                                  final hasVideo = lesson.videoDriveLink
                                      .trim()
                                      .isNotEmpty;
                                  final canPlay =
                                      hasVideo && canAccessLearningContent;
                                  final lessonKey = _lessonKey(module, lesson);
                                  final isLessonCompleted = _completedLessonKeys
                                      .contains(lessonKey);
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withAlpha(90),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withAlpha(60),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${index + 1}',
                                            style: textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF1D4ED8,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                lesson.title,
                                                style: textTheme.titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                lesson.duration.isEmpty
                                                    ? 'Duration not specified'
                                                    : lesson.duration,
                                                style: textTheme.bodySmall,
                                              ),
                                              if (isLessonCompleted)
                                                Text(
                                                  'Completed',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: const Color(
                                                          0xFF16A34A,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                                  canAccess:
                                                      canAccessLearningContent,
                                                )
                                              : null,
                                          icon: Icon(
                                            canPlay
                                                ? Icons.play_circle_fill_rounded
                                                : Icons.lock_outline_rounded,
                                            size: 28,
                                            color: canPlay
                                                ? theme.colorScheme.primary
                                                : const Color(0xFF94A3B8),
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
                                })
                                .toList(growable: false),
                          ),
                        ),
                        if (_completedModules.contains(module.orderIndex))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
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
                        if (module.quizQuestions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: _ModuleQuizCard(
                              module: module,
                              questionCount: module.quizQuestions.length,
                              isLocked: _moduleQuizLocked(module),
                              isCompleted: _moduleQuizCompleted(module),
                              isModuleCompleted: _isModuleCompleted(module),
                              bestScore: _moduleQuizBestScore(module),
                              canAccess: canAccessLearningContent,
                              onStart: () => _openModuleQuiz(
                                course: course,
                                module: module,
                                shouldStoreResult: isStudent && isEnrolled,
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
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${modulesWithMaterials.fold<int>(0, (sum, m) => sum + m.studyMaterials.length)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
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
                    child: Text(
                      'Only enrolled students, mentor, or admin can access materials.',
                    ),
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
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...module.studyMaterials.map((material) {
                          final hasDrive = material.driveLink.trim().isNotEmpty;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: hasDrive
                                ? () => _openMaterialLink(material.driveLink)
                                : null,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(material.title),
                            subtitle: Text(
                              hasDrive ? material.driveLink : 'No Drive link',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              hasDrive
                                  ? Icons.open_in_new_rounded
                                  : Icons.lock_outline_rounded,
                              color: hasDrive
                                  ? theme.colorScheme.primary
                                  : const Color(0xFF94A3B8),
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
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalQuizQuestions questions',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!canAccessLearningContent)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Only enrolled students, mentor, or admin can attempt this quiz.',
                  ),
                )
              else if (!_isFinalQuizUnlocked(course))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Complete 100% of this course to unlock the final quiz.',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (totalQuizQuestions < 10)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Quiz is being prepared. Minimum 10 questions required.',
                    style: textTheme.bodyMedium,
                  ),
                )
              else if (_quizLocked || _quizRewatchRequired)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Course quiz locked after 5 attempts.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (!_quizStarted)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attempts: $_quizAttempts/5 • Best: $_quizBestScore',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openCourseQuiz(
                          course: course,
                          shouldStoreResult: isStudent && isEnrolled,
                        ),
                        icon: const Icon(Icons.quiz_rounded),
                        label: Text(
                          _quizCompleted
                              ? 'Open Course Quiz'
                              : 'Start Final Quiz',
                        ),
                      ),
                    ),
                  ],
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
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedQuizQuestions[_quizIndex].question,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
            child: CourseCtaButton(
              label: cta.label,
              isLoading: _ctaLoading,
              onPressed: cta.isEnabled
                  ? () => _handleCtaAction(
                      course: course,
                      cta: cta,
                      canAccess: canAccessLearningContent,
                      isEnrolled: isEnrolled,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleQuizCard extends StatelessWidget {
  const _ModuleQuizCard({
    required this.module,
    required this.questionCount,
    required this.isLocked,
    required this.isCompleted,
    required this.isModuleCompleted,
    required this.bestScore,
    required this.canAccess,
    required this.onStart,
  });

  final CourseModule module;
  final int questionCount;
  final bool isLocked;
  final bool isCompleted;
  final bool isModuleCompleted;
  final int bestScore;
  final bool canAccess;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPrepared = questionCount >= 10;
    final canStart = canAccess && isModuleCompleted && isPrepared && !isLocked;

    final Color accent;
    final IconData icon;
    final String status;
    if (isCompleted) {
      accent = const Color(0xFF16A34A);
      icon = Icons.verified_rounded;
      status = 'Passed';
    } else if (isLocked) {
      accent = scheme.error;
      icon = Icons.lock_outline_rounded;
      status = 'Rewatch needed';
    } else if (!isModuleCompleted) {
      accent = const Color(0xFFF59E0B);
      icon = Icons.flag_outlined;
      status = 'Unlocks after module';
    } else if (!isPrepared) {
      accent = const Color(0xFF64748B);
      icon = Icons.pending_actions_rounded;
      status = 'Preparing';
    } else {
      accent = scheme.primary;
      icon = Icons.quiz_rounded;
      status = 'Ready';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Module quiz',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _supportingText(
                        isPrepared: isPrepared,
                        canAccess: canAccess,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withAlpha(170),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetric(
                icon: Icons.library_books_outlined,
                label: '$questionCount questions',
              ),
              _MiniMetric(
                icon: Icons.workspace_premium_outlined,
                label: 'Best $bestScore',
              ),
              _MiniMetric(
                icon: Icons.checklist_rounded,
                label: isModuleCompleted ? 'Module done' : 'Module pending',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStart ? onStart : null,
              icon: Icon(
                isCompleted ? Icons.refresh_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(isCompleted ? 'Retake quiz' : 'Start quiz'),
            ),
          ),
        ],
      ),
    );
  }

  String _supportingText({required bool isPrepared, required bool canAccess}) {
    if (!canAccess) {
      return 'Only enrolled students, mentor, or admin can open this quiz.';
    }
    if (!isModuleCompleted) {
      return 'Complete every lesson in this module to unlock the mentor quiz.';
    }
    if (!isPrepared) {
      return 'The mentor needs at least 10 questions before this quiz opens.';
    }
    if (isLocked) {
      return 'Rewatch this module lesson to unlock another attempt.';
    }
    return 'Answer 5 random questions from this module.';
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withAlpha(35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
