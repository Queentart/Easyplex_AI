# nginx image serving a PRE-BUILT Flutter Web bundle.
#
# Why prebuilt (not in-container multistage): the in-container build needs the
# Flutter SDK image from ghcr.io, which is not reachable in this environment
# (DNS for ghcr.io fails). The host already has the exact Flutter toolchain that
# builds this project, so we build on the host and copy the result here.
#
# Build the bundle FIRST (from the frontend/ dir), then `docker compose build`:
#   flutter build web --release --dart-define=API_BASE_URL=/api/v1
#
# ── Hermetic alternative (use where ghcr.io IS reachable, e.g. CI) ────────────
#   FROM ghcr.io/cirruslabs/flutter:stable AS build
#   WORKDIR /app
#   COPY pubspec.* ./
#   RUN flutter pub get
#   COPY . .
#   ARG API_BASE_URL=/api/v1
#   RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}
#   FROM nginx:alpine
#   COPY nginx.conf /etc/nginx/conf.d/default.conf
#   COPY --from=build /app/build/web /usr/share/nginx/html
# ─────────────────────────────────────────────────────────────────────────────

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
EXPOSE 80
