// Public API for the web-native HTML5 `<video>` player + browser download.
//
// The course video feature plays/downloads videos through a presigned URL.
// Rather than depend on the `video_player` plugin (whose web implementation is
// not reliably registered and throws "init() has not been implemented"), we
// embed a real `<video>` element via HtmlElementView on web. On non-web
// platforms the stub renders a friendly notice.
//
// Implementation is selected at compile time via conditional import:
//   - web   → web_video_player_web.dart   (dart:ui_web + package:web)
//   - other → web_video_player_stub.dart  (no-op fallback)
export 'web_video_player_stub.dart'
    if (dart.library.js_interop) 'web_video_player_web.dart';
