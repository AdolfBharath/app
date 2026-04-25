import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/web_helper.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../features/student/presentation/widgets/ask_question_modal.dart';
import '../config/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.lessonTitle,
    required this.videoUrl,
    this.description = '',
    this.transcript = '',
    required this.courseId,
    required this.moduleId,
    required this.lessonId,
    required this.mentorId,
    this.courseTitle,
    this.moduleTitle,
  });

  final String lessonTitle;
  final String videoUrl;
  final String description;
  final String transcript;
  final String courseId;
  final String moduleId;
  final String lessonId;
  final String mentorId;
  final String? courseTitle;
  final String? moduleTitle;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late final dynamic _controller; // WebViewController on mobile
  bool _loading = true;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'video-player-${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      // Register the iframe for Web using the platform-safe helper
      WebHelper.registerVideoIframe(_viewId, widget.videoUrl);
      _loading = false;
    } else {
      // Initialize WebView for Mobile
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted) return;
              setState(() => _loading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.videoUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = widget.description.trim().isNotEmpty;
    final hasTranscript = widget.transcript.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lessonTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                if (kIsWeb)
                  HtmlElementView(viewType: _viewId)
                else
                  WebViewWidget(controller: _controller as WebViewController),
                if (_loading && !kIsWeb)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          if (hasDescription || hasTranscript)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasDescription) ...[
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.description),
                    ],
                    if (hasDescription && hasTranscript)
                      const SizedBox(height: 10),
                    if (hasTranscript) ...[
                      const Text(
                        'Transcript',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.transcript),
                    ],
                  ],
                ),
              ),
            ),
          _buildBottomActionArea(context),
        ],
      ),
    );
  }

  Widget _buildBottomActionArea(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isStudent = auth.currentRole == UserRole.student;

    if (!isStudent) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stuck on this lesson?',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Ask your mentor for help',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LmsAdminTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AskQuestionModal(
                  courseId: widget.courseId,
                  moduleId: widget.moduleId,
                  lessonId: widget.lessonId,
                  mentorId: widget.mentorId,
                  courseTitle: widget.courseTitle,
                  moduleTitle: widget.moduleTitle,
                  lessonTitle: widget.lessonTitle,
                ),
              );
            },
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Ask Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LmsAdminTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
