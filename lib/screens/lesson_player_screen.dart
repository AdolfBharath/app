import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.lessonTitle,
    required this.videoUrl,
    this.description = '',
    this.transcript = '',
  });

  final String lessonTitle;
  final String videoUrl;
  final String description;
  final String transcript;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
                WebViewWidget(controller: _controller),
                if (_loading)
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
        ],
      ),
    );
  }
}
