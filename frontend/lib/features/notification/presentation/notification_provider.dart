import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Notification list + realtime stream
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the current user's notifications and keeps the list live by opening
/// the realtime WebSocket: new pushes are prepended to the front of the list.
///
/// Mark-read / mark-all-read mutate state optimistically (and roll back on
/// failure) so the badge and list update instantly.
class NotificationListNotifier extends AsyncNotifier<List<AppNotification>> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;

  @override
  Future<List<AppNotification>> build() async {
    // Tear down the socket when the notifier is disposed.
    ref.onDispose(_closeSocket);
    final list = await _fetch();
    // Connect after the initial load so the list exists before pushes arrive.
    unawaited(_connectSocket());
    return list;
  }

  Future<List<AppNotification>> _fetch() async {
    final page = await ref.read(notificationRepositoryProvider).listNotifications();
    return page.notifications;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Opens the realtime socket and prepends each incoming notification.
  Future<void> _connectSocket() async {
    try {
      final channel = await ref.read(notificationRepositoryProvider).connect();
      if (channel == null) return;
      _channel = channel;
      _wsSub = channel.stream.listen(
        _onWsFrame,
        onError: (_) {},
        onDone: () {},
        cancelOnError: false,
      );
    } catch (_) {
      // Realtime is best-effort; REST already populated the list.
    }
  }

  void _onWsFrame(dynamic raw) {
    final notification = NotificationRepository.parseWsMessage(raw);
    if (notification == null) return;
    final current = state.value ?? const <AppNotification>[];
    // Guard against duplicates (e.g. a push echoing an item already loaded).
    if (current.any((n) => n.id == notification.id)) return;
    state = AsyncData([notification, ...current]);
  }

  Future<void> _closeSocket() async {
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  /// Optimistically marks [notificationId] read, rolling back on failure.
  Future<void> markRead(int notificationId) async {
    final current = state.value;
    if (current == null) return;
    final target = current.where((n) => n.id == notificationId);
    if (target.isEmpty || target.first.isRead) return;

    state = AsyncData([
      for (final n in current)
        if (n.id == notificationId) n.copyWith(isRead: true) else n,
    ]);
    try {
      await ref.read(notificationRepositoryProvider).markRead(notificationId);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Optimistically marks every notification read, rolling back on failure.
  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;
    if (current.every((n) => n.isRead)) return;

    state = AsyncData([for (final n in current) n.copyWith(isRead: true)]);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, List<AppNotification>>(
  NotificationListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Unread count (AppBar bell badge)
/// ─────────────────────────────────────────────────────────────────────────

/// Derived unread-notification count for the AppBar bell badge.
///
/// Bind this in `top_bar.dart`: `ref.watch(unreadNotificationCountProvider)`.
/// Returns 0 while loading or on error so the badge degrades gracefully.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationListProvider);
  return async.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
