// lib/utils/web_helper_web.dart

import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

/// Web-specific implementation using package:web and dart:ui_web.
void registerVideoIframeImpl(String viewId, String videoUrl) {
  ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = videoUrl
      ..style.border = 'none'
      ..allow = 'autoplay; fullscreen'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
}
