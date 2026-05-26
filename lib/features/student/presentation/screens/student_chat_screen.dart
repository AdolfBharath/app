import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../providers/student_provider.dart';

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final student = context.read<StudentProvider>();
      setState(() {
        _messages.add(
          _ChatMessage.assistant(
            _welcomeMessage(
              auth.currentUser?.username ?? auth.currentUser?.name ?? 'there',
              student,
            ),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? prompt]) {
    final text = (prompt ?? _controller.text).trim();
    if (text.isEmpty) return;

    final student = context.read<StudentProvider>();
    final auth = context.read<AuthProvider>();

    setState(() {
      _messages.add(_ChatMessage.user(text));
      _messages.add(_ChatMessage.assistant(_buildReply(text, student, auth)));
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  String _welcomeMessage(String name, StudentProvider student) {
    final enrolled = student.enrolledCourses.length;
    final streak = student.streakCount;
    return 'Hi $name. I can help you understand the app, courses, mentors, streaks, quizzes, rewards, shop, batches, and support. You currently have $enrolled enrolled course(s) and a $streak day streak.';
  }

  String _buildReply(
    String prompt,
    StudentProvider student,
    AuthProvider auth,
  ) {
    final q = prompt.toLowerCase();
    if (_matches(q, ['course', 'classes', 'lesson', 'module', 'learn'])) {
      return _courseReply(student);
    }
    if (_matches(q, ['mentor', 'teacher', 'instructor', 'faculty'])) {
      return _mentorReply(student);
    }
    if (_matches(q, ['streak', 'coin', 'reward', 'daily'])) {
      return _streakReply(student);
    }
    if (_matches(q, ['quiz', 'test', 'attempt', 'question'])) {
      return _quizReply(student);
    }
    if (_matches(q, ['shop', 'market', 'purchase', 'buy'])) {
      return _shopReply(student);
    }
    if (_matches(q, ['batch', 'chat', 'discussion'])) {
      return _batchReply();
    }
    if (_matches(q, ['support', 'help', 'admin', 'contact'])) {
      return _supportReply();
    }
    if (_matches(q, ['profile', 'notification', 'theme', 'dark'])) {
      return _featureReply(auth);
    }
    return _overviewReply(student);
  }

  bool _matches(String text, List<String> words) {
    return words.any(text.contains);
  }

  String _courseReply(StudentProvider student) {
    final all = student.allCourses;
    final enrolled = student.enrolledCourses;
    final visible = enrolled.isNotEmpty ? enrolled : all.take(4).toList();
    final buffer = StringBuffer();

    buffer.writeln(
      enrolled.isEmpty
          ? 'Courses are shown on the Home and Courses tabs. You can search, filter by category, open details, enroll, watch lessons, access study materials, and attempt module quizzes after completing modules.'
          : 'Your enrolled courses are available in the Courses tab. Open a course to continue lessons, view study materials, ask mentor questions, and unlock module quizzes after completing the module.',
    );

    if (visible.isNotEmpty) {
      buffer.writeln('\nCourses I can see:');
      for (final course in visible.take(5)) {
        final progress = student.getCourseProgress(course.id);
        buffer.writeln(
          '- ${course.title}: ${(progress * 100).round()}% progress, ${course.modules.length} module(s), mentor ${course.instructorName}.',
        );
      }
    }

    return buffer.toString().trim();
  }

  String _mentorReply(StudentProvider student) {
    final courses = student.enrolledCourses.isNotEmpty
        ? student.enrolledCourses
        : student.allCourses;
    if (courses.isEmpty) {
      return 'Mentors are assigned to courses by the admin. Once courses load, open any course detail page to see its mentor or instructor name.';
    }

    final unique = <String>{};
    final lines = <String>[];
    for (final course in courses) {
      final mentor = course.instructorName.trim().isEmpty
          ? 'Academy Mentor'
          : course.instructorName.trim();
      final key = '$mentor|${course.title}';
      if (unique.add(key)) {
        lines.add('- $mentor mentors ${course.title}.');
      }
      if (lines.length >= 5) break;
    }

    return 'Mentors guide your course learning, reply to lesson questions, review doubts, and support batch announcements.\n\n${lines.join('\n')}';
  }

  String _streakReply(StudentProvider student) {
    return 'Your streak tracks consistent daily app activity. You are currently on a ${student.streakCount} day streak with ${student.coins} coin(s). Logging in daily keeps the streak active, and coins can be used for course enrollment or shop rewards when enabled.';
  }

  String _quizReply(StudentProvider student) {
    final quizCourses = student.enrolledCourses
        .where(
          (course) => course.modules.any((m) => m.quizQuestions.isNotEmpty),
        )
        .toList();
    final extra = quizCourses.isEmpty
        ? ''
        : '\n\nCourses with module quizzes: ${quizCourses.take(4).map((c) => c.title).join(', ')}.';
    return 'Module quizzes are created by mentors inside each module. A quiz opens only after you complete that module. Each attempt asks random questions, saves your score, and may lock after repeated failed attempts until you rewatch the module lesson.$extra';
  }

  String _shopReply(StudentProvider student) {
    return 'The Shop tab lets you redeem or buy configured rewards with coins. You have ${student.coins} coin(s), and ${student.purchasedItems.length} purchased item(s) are currently saved for your account.';
  }

  String _batchReply() {
    return 'The Batch tab shows your batch learning space. Use it for batch information, discussions, announcements, and shared learning updates from mentors.';
  }

  String _supportReply() {
    return 'For account or app issues, open Profile, then Support. You can send a message to the admin team. For lesson doubts, open the lesson or course area and ask your mentor so the question stays linked to the course/module.';
  }

  String _featureReply(AuthProvider auth) {
    final name =
        auth.currentUser?.name ?? auth.currentUser?.username ?? 'your account';
    return 'In $name, the student app includes Home discovery, My Courses, Batch, Shop, Profile, notifications, dark/light theme, course progress, module quizzes, study materials, mentor questions, coins, streaks, and support messages.';
  }

  String _overviewReply(StudentProvider student) {
    return 'Here is what I can help with:\n- Courses: explore, enroll, continue lessons, track progress.\n- Mentors: see who guides a course and ask lesson questions.\n- Streaks and coins: daily activity, rewards, shop usage.\n- Quizzes: mentor-created module quizzes unlock after module completion.\n- App help: batches, notifications, profile, theme, support, and shop.\n\nTry asking “What courses do I have?”, “Explain streak”, or “How do module quizzes work?”';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suggestions = const [
      'Explain my courses',
      'How do streaks work?',
      'Tell me about mentors',
      'How do quizzes unlock?',
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Ask AI',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Course guidance • app help • streaks • mentor info',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: scheme.onSurface.withAlpha(153),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = suggestions[index];
                  return ActionChip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(item),
                    onPressed: () => _send(item),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: suggestions.length,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _MessageBubble(message: message);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask about courses, mentor, streaks...',
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: scheme.onSurface.withAlpha(20),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: scheme.onSurface.withAlpha(20),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    width: 46,
                    child: FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: Radius.circular(isUser ? 4 : 18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
          ),
          border: isUser
              ? null
              : Border.all(color: scheme.onSurface.withAlpha(16)),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.45,
            color: isUser ? scheme.onPrimary : scheme.onSurface,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  factory _ChatMessage.user(String text) =>
      _ChatMessage(text: text, isUser: true);

  factory _ChatMessage.assistant(String text) =>
      _ChatMessage(text: text, isUser: false);

  final String text;
  final bool isUser;
}
