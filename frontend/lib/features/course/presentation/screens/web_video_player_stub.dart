import 'package:flutter/widgets.dart';

/// Non-web fallback for the HTML5 video player.
///
/// The course player is web-only (it embeds a real `<video>` element). On other
/// platforms we render a short notice instead of pulling in a native plugin.
Widget buildVideoPlayer(String url) {
  return const Center(
    child: Text('웹에서 재생 가능합니다.'),
  );
}

/// Non-web fallback for the browser download trigger. No-op off the web.
void triggerDownload(String url, String filename) {
  // Downloads are handled by the browser on web only; nothing to do elsewhere.
}
