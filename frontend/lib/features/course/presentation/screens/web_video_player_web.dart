import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Monotonic counter so every embedded player gets a unique platform-view type.
int _seq = 0;

/// Builds a web-native HTML5 `<video>` element wrapped in an [HtmlElementView].
///
/// [url] is a presigned, range-capable GET URL (so the browser can seek). The
/// element shows native controls but hides the browser's own download button
/// (`controlsList=nodownload`) — downloads go through [triggerDownload] with an
/// attachment URL so the file saves with a friendly name.
Widget buildVideoPlayer(String url) {
  final viewType = 'course-video-${_seq++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final v = web.HTMLVideoElement()
      ..src = url
      ..controls = true
      ..autoplay = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';
    v.setAttribute('controlsList', 'nodownload');
    return v;
  });
  return HtmlElementView(viewType: viewType);
}

/// Triggers a browser download of [url], saving it as [filename].
///
/// The server sets `Content-Disposition: attachment` on the presigned URL, and
/// the `download` attribute supplies the suggested name.
void triggerDownload(String url, String filename) {
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..target = '_blank';
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
}
