// lib/utils/web_helper.dart

import 'web_helper_stub.dart'
    if (dart.library.js_interop) 'web_helper_web.dart' as impl;

/// Helper class to handle web-specific logic like registering platform view factories
/// in a cross-platform safe way.
class WebHelper {
  static void registerVideoIframe(String viewId, String videoUrl) {
    impl.registerVideoIframeImpl(viewId, videoUrl);
  }
}
