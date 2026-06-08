"""Static file server for a built Flutter web app — review-friendly.

Usage: python serve_web.py <web_root> <port>

Why this exists: `flutter run -d chrome` is debug-mode and breaks the tab on every
restart; and Flutter web's PWA service worker aggressively caches assets so a
plain refresh keeps showing a STALE build even after `flutter build web`.

This server:
  - is multithreaded (handles a browser's concurrent asset requests),
  - sends no-store headers (so refreshes always fetch the latest build),
  - SPA-falls back to index.html for client-side routes (go_router path URLs),
  - serves a SELF-DESTRUCTING `flutter_service_worker.js` so any previously
    registered service worker unregisters itself + clears caches on next check,
  - injects a tiny unregister/clear-caches snippet into index.html as a belt-and
    -suspenders, so a single refresh fully cleans a stale PWA and reloads once.

Pair it with `flutter build web --pwa-strategy=none` so no new SW is generated.
"""
import os
import posixpath
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.abspath(sys.argv[1])
PORT = int(sys.argv[2])

# A service worker that erases itself: clears all caches, unregisters, and
# reloads any open clients. Served in place of Flutter's flutter_service_worker.js
# so browsers that still have the old SW registered get cleaned on next update
# check (browsers re-fetch the SW script on navigation).
SELF_DESTRUCT_SW = b"""
self.addEventListener('install', function(e){ self.skipWaiting(); });
self.addEventListener('activate', function(e){
  e.waitUntil((async function(){
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map(function(k){ return caches.delete(k); }));
    } catch (err) {}
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach(function(c){ c.navigate(c.url); });
  })());
});
"""

# Injected into index.html <head>: unregister any SW + clear caches, reload once.
INJECT = b"""<script>
(function(){
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.getRegistrations().then(function(rs){
    if (!rs.length) return;
    Promise.all(rs.map(function(r){ return r.unregister(); })).then(function(){
      var done = function(){
        if (!sessionStorage.getItem('__sw_cleared__')) {
          sessionStorage.setItem('__sw_cleared__', '1');
          location.reload();
        }
      };
      if (window.caches && caches.keys) {
        caches.keys().then(function(ks){
          return Promise.all(ks.map(function(k){ return caches.delete(k); }));
        }).then(done, done);
      } else { done(); }
    });
  });
})();
</script>
"""


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def _send(self, body: bytes, content_type: str, code: int = 200):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _index_html(self) -> bytes:
        with open(os.path.join(ROOT, "index.html"), "rb") as f:
            html = f.read()
        if b"__sw_cleared__" not in html:
            if b"<head>" in html:
                html = html.replace(b"<head>", b"<head>" + INJECT, 1)
            else:
                html = INJECT + html
        return html

    def do_GET(self):  # noqa: N802
        rel = self.path.split("?", 1)[0].split("#", 1)[0]
        name = posixpath.basename(rel)

        # 1) Self-destruct any previously-registered Flutter service worker.
        if name == "flutter_service_worker.js":
            return self._send(SELF_DESTRUCT_SW, "application/javascript")

        # 2) index.html (root, explicit, or SPA fallback) — inject SW cleanup.
        target = os.path.join(ROOT, rel.lstrip("/"))
        is_index = rel in ("/", "/index.html") or (
            not os.path.exists(target) and not os.path.splitext(rel)[1]
        )
        if is_index:
            return self._send(self._index_html(), "text/html; charset=utf-8")

        # 3) Everything else: normal static file serving.
        return super().do_GET()

    def do_HEAD(self):  # noqa: N802
        return self.do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):  # quieter
        pass


ThreadingHTTPServer.allow_reuse_address = True
ThreadingHTTPServer.daemon_threads = True
with ThreadingHTTPServer(("127.0.0.1", PORT), Handler) as httpd:
    print(f"Serving {ROOT} at http://localhost:{PORT}")
    httpd.serve_forever()
