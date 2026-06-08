import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/cohort_filter.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Channel list
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the live chat channels available to the current user.
///
/// Cohort scoping differs by role:
///   - STUDENTS carry a `cohort_id`, so the backend already scopes
///     `GET /chat/channels` to their cohort. We send NO `cohort_id` param and
///     let the backend default to the caller's own cohort.
///   - STAFF (admin_ops / instructor / tech_support) have `cohort_id == null`,
///     so without an explicit param the backend matches null-cohort channels
///     (of which there are none) and returns an empty list. We therefore
///     forward the globally-selected cohort ([selectedCohortProvider]) as the
///     `cohort_id` param so staff see that cohort's channels.
///
/// When a staff user has "기수 전체" selected (no specific cohort), this provider
/// is NOT the one driving the screen — the screen switches to the aggregated,
/// grouped-by-cohort view ([chatAggregatedChannelsProvider]) instead. For a
/// student, or for staff with a specific cohort selected, this flat list is used.
class ChatChannelListNotifier extends AsyncNotifier<List<ChatChannel>> {
  @override
  Future<List<ChatChannel>> build() {
    // Rebuild whenever the globally-selected cohort changes so switching the
    // nav cohort refreshes the staff channel list.
    final selectedCohort = ref.watch(selectedCohortProvider);
    return _fetch(selectedCohort);
  }

  Future<List<ChatChannel>> _fetch(int? selectedCohort) {
    final user = ref.read(currentUserProvider);
    // A student is scoped by the backend to their own cohort; staff (no
    // cohort of their own) must pass the selected cohort explicitly.
    final isStudent = user?.role == AppRoles.student;
    final cohortId = isStudent ? null : selectedCohort;
    return ref.read(chatRepositoryProvider).listChannels(cohortId: cohortId);
  }

  Future<void> refresh() async {
    final selectedCohort = ref.read(selectedCohortProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(selectedCohort));
  }
}

final chatChannelListProvider =
    AsyncNotifierProvider<ChatChannelListNotifier, List<ChatChannel>>(
  ChatChannelListNotifier.new,
);

/// True when the current user is STAFF (no cohort of their own) AND has "기수
/// 전체" selected, i.e. no specific cohort is in scope. In this state the screen
/// renders the aggregated, grouped-by-cohort view rather than a single flat list.
final chatStaffAllCohortsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  final selectedCohort = ref.watch(selectedCohortProvider);
  final isStudent = user?.role == AppRoles.student;
  return !isStudent && selectedCohort == null;
});

/// ─────────────────────────────────────────────────────────────────────────
/// Aggregated channel list (STAFF, "기수 전체")
/// ─────────────────────────────────────────────────────────────────────────

/// The channels of a single cohort, used to render a grouped section header
/// ("1기") followed by that cohort's channel rows.
class ChatCohortGroup {
  const ChatCohortGroup({required this.cohort, required this.channels});

  final CohortOption cohort;
  final List<ChatChannel> channels;
}

/// Per-cohort channel fetch, keyed by cohort id, so each cohort's
/// `GET /chat/channels?cohort_id=…` result is cached and shared. Used by the
/// aggregated staff view to fan out one request per cohort.
final chatChannelsForCohortProvider =
    FutureProvider.family<List<ChatChannel>, int>((ref, cohortId) {
  return ref.watch(chatRepositoryProvider).listChannels(cohortId: cohortId);
});

/// Aggregated, grouped-by-cohort channels for STAFF viewing "기수 전체".
///
/// Reads the role-scoped [cohortOptionsProvider] (operations sees all cohorts,
/// an instructor sees their assigned cohorts), then fans out one cached
/// per-cohort fetch ([chatChannelsForCohortProvider]) for each. Cohorts that
/// end up with no channels are omitted from the result so the grouped list only
/// shows sections that actually contain channels.
///
/// Resolves once every per-cohort fetch settles; if any fetch fails the whole
/// aggregate surfaces that error (the screen offers a retry).
final chatAggregatedChannelsProvider =
    FutureProvider<List<ChatCohortGroup>>((ref) async {
  final cohorts = await ref.watch(cohortOptionsProvider.future);
  if (cohorts.isEmpty) return const <ChatCohortGroup>[];

  final groups = await Future.wait(
    cohorts.map((cohort) async {
      final channels =
          await ref.watch(chatChannelsForCohortProvider(cohort.id).future);
      return ChatCohortGroup(cohort: cohort, channels: channels);
    }),
  );

  // Omit cohorts that have no channels so the grouped view only shows
  // sections that actually contain something.
  return groups.where((g) => g.channels.isNotEmpty).toList();
});

/// ─────────────────────────────────────────────────────────────────────────
/// Connection lifecycle
/// ─────────────────────────────────────────────────────────────────────────

/// Live socket connection phase, surfaced in the UI as a status banner.
enum ChatConnectionStatus { connecting, connected, disconnected }

/// Immutable snapshot of a chat room: its messages plus the socket state.
class ChatRoomState {
  const ChatRoomState({
    required this.messages,
    required this.connection,
    this.error,
  });

  final List<ChatMessage> messages;
  final ChatConnectionStatus connection;

  /// Non-fatal connection / send error to surface (e.g. via a banner). Distinct
  /// from the [AsyncError] state, which represents a failed initial history load.
  final String? error;

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    ChatConnectionStatus? connection,
    String? error,
    bool clearError = false,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      connection: connection ?? this.connection,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Chat room (history + live socket)
/// ─────────────────────────────────────────────────────────────────────────

/// Drives a single chat room:
///   1. loads message history over REST,
///   2. opens the authenticated WebSocket,
///   3. appends inbound `{"type":"message","data":{…}}` frames,
///   4. sends with optimistic insert → server echo reconciliation,
///   5. tracks connection status and auto-reconnects with backoff,
///   6. tears the socket down on dispose.
///
/// The family argument (channel id) is captured in [channelId] — Riverpod 3.x
/// non-codegen notifiers don't receive it in [build].
class ChatRoomNotifier extends AsyncNotifier<ChatRoomState> {
  ChatRoomNotifier(this.channelId);

  final int channelId;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  static const _maxReconnectDelay = Duration(seconds: 15);

  @override
  Future<ChatRoomState> build() async {
    // Ensure every resource is released when the provider is disposed.
    ref.onDispose(_teardown);

    final messages =
        await ref.read(chatRepositoryProvider).listMessages(channelId);
    // Kick off the socket after history is in place; do not await — the room is
    // usable immediately and the status banner reflects the handshake.
    _openSocket();
    return ChatRoomState(
      messages: messages,
      connection: ChatConnectionStatus.connecting,
    );
  }

  /// Current in-memory state, or an empty connecting snapshot before the first
  /// build resolves. Helper for the mutation methods below.
  ChatRoomState get _current =>
      state.value ??
      const ChatRoomState(
        messages: [],
        connection: ChatConnectionStatus.connecting,
      );

  // ── Socket management ───────────────────────────────────────────────────

  Future<void> _openSocket() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    final token =
        await ref.read(authStorageProvider).readAccessToken() ?? '';
    if (_disposed) return;
    if (token.isEmpty) {
      _setConnection(
        ChatConnectionStatus.disconnected,
        error: '인증 정보가 없어 채팅에 연결할 수 없습니다.',
      );
      return;
    }

    _setConnection(ChatConnectionStatus.connecting, clearError: true);

    try {
      final socket = ref
          .read(chatRepositoryProvider)
          .connect(channelId: channelId, accessToken: token);
      _socket = socket;

      // `ready` completes once the handshake succeeds.
      await socket.ready;
      if (_disposed) {
        await socket.sink.close();
        return;
      }
      _reconnectAttempts = 0;
      _setConnection(ChatConnectionStatus.connected, clearError: true);

      _socketSub = socket.stream.listen(
        _onFrame,
        onError: (_) => _onSocketClosed(),
        onDone: _onSocketClosed,
        cancelOnError: true,
      );
    } catch (_) {
      _onSocketClosed();
    }
  }

  /// Parses an inbound frame and appends the message. The backend wraps each
  /// broadcast as `{"type":"message","data":{id,sender_id,content,created_at}}`.
  void _onFrame(dynamic raw) {
    if (_disposed || raw is! String) return;
    Map<String, dynamic>? frame;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) frame = decoded;
    } catch (_) {
      return; // ignore malformed frames
    }
    if (frame == null || frame['type'] != 'message') return;

    final data = frame['data'];
    if (data is! Map) return;
    final message =
        ChatMessage.fromJson(data.map((k, v) => MapEntry(k.toString(), v)));
    _appendConfirmed(message);
  }

  /// Inserts a server-confirmed message, replacing the matching optimistic
  /// placeholder (same sender + content, still pending) when present so the
  /// sender does not see a duplicate.
  void _appendConfirmed(ChatMessage message) {
    final messages = [..._current.messages];

    // Drop if we already have this server id (idempotent re-delivery).
    if (messages.any((m) => m.id == message.id)) return;

    final optimisticIndex = messages.indexWhere(
      (m) =>
          m.isOptimistic &&
          m.senderId == message.senderId &&
          m.content == message.content &&
          _sameAttachments(m.attachments, message.attachments),
    );
    if (optimisticIndex != -1) {
      messages[optimisticIndex] = message;
    } else {
      messages.add(message);
    }
    state = AsyncData(_current.copyWith(messages: messages));
  }

  void _onSocketClosed() {
    if (_disposed) return;
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    _setConnection(ChatConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  /// Exponential backoff (1s, 2s, 4s … capped at 15s) so a flapping server does
  /// not get hammered.
  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final seconds = (1 << _reconnectAttempts).clamp(1, _maxReconnectDelay.inSeconds);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _openSocket);
  }

  void _setConnection(
    ChatConnectionStatus status, {
    String? error,
    bool clearError = false,
  }) {
    if (_disposed) return;
    state = AsyncData(
      _current.copyWith(
        connection: status,
        error: error,
        clearError: clearError,
      ),
    );
  }

  /// True when two attachment lists reference the same files (by key, in order).
  /// Used to reconcile an optimistic placeholder with its server echo even when
  /// the message has no text content.
  static bool _sameAttachments(
    List<ChatAttachment> a,
    List<ChatAttachment> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].fileKey != b[i].fileKey) return false;
    }
    return true;
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Sends [text] (and optional [attachments]) over the socket with an
  /// optimistic insert. The server echoes the persisted message back (over the
  /// same channel), which reconciles the placeholder via [_appendConfirmed].
  ///
  /// Wire protocol: for a text-only message a RAW TEXT frame works; when there
  /// are attachments we send JSON `{"content": ..., "attachments":[...]}`. We
  /// always send JSON when attachments are present and plain text otherwise —
  /// both are accepted by the backend.
  ///
  /// Returns `true` if the frame was handed to the socket (an optimistic bubble
  /// was inserted), `false` if it could not be sent (e.g. disconnected, or
  /// nothing to send).
  bool send(
    String text, {
    required int currentUserId,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return false;

    final socket = _socket;
    if (socket == null ||
        _current.connection != ChatConnectionStatus.connected) {
      _setConnection(
        _current.connection,
        error: '연결이 끊어져 메시지를 보낼 수 없습니다. 재연결 중입니다.',
      );
      return false;
    }

    final optimistic = ChatMessage.optimistic(
      senderId: currentUserId,
      content: trimmed,
      attachments: attachments,
    );
    state = AsyncData(
      _current.copyWith(
        messages: [..._current.messages, optimistic],
        clearError: true,
      ),
    );

    try {
      if (attachments.isEmpty) {
        socket.sink.add(trimmed);
      } else {
        socket.sink.add(jsonEncode({
          'content': trimmed,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        }));
      }
      return true;
    } catch (_) {
      _setConnection(
        ChatConnectionStatus.disconnected,
        error: '메시지 전송에 실패했습니다. 재연결 중입니다.',
      );
      _onSocketClosed();
      return false;
    }
  }

  /// Picks-up where the composer's file picker left off: uploads each picked
  /// file (presign → PUT) then sends a single message carrying the resulting
  /// attachments (plus optional [text]). Returns `true` on a successful send.
  ///
  /// Upload happens BEFORE the optimistic insert so a failed upload surfaces an
  /// error without leaving a stuck bubble; the brief upload latency is covered
  /// by the composer's spinner.
  Future<bool> uploadAndSend({
    required List<({String fileName, String contentType, Uint8List bytes})>
        files,
    required int currentUserId,
    String text = '',
  }) async {
    if (files.isEmpty) return send(text, currentUserId: currentUserId);

    if (_current.connection != ChatConnectionStatus.connected) {
      _setConnection(
        _current.connection,
        error: '연결이 끊어져 파일을 보낼 수 없습니다. 재연결 중입니다.',
      );
      return false;
    }

    final repo = ref.read(chatRepositoryProvider);
    final uploaded = <ChatAttachment>[];
    try {
      for (final f in files) {
        uploaded.add(await repo.uploadAttachment(
          fileName: f.fileName,
          contentType: f.contentType,
          bytes: f.bytes,
        ));
      }
    } catch (e) {
      _setConnection(
        _current.connection,
        error: e is ChatException ? e.message : '파일 업로드에 실패했습니다.',
      );
      return false;
    }

    return send(text, currentUserId: currentUserId, attachments: uploaded);
  }

  /// Manual reconnect (wired to the "재연결" affordance). Resets backoff so the
  /// attempt is immediate.
  Future<void> reconnect() async {
    _reconnectAttempts = 0;
    await _openSocket();
  }

  /// Re-fetches history (e.g. after the user pulls to refresh). Keeps the live
  /// socket open.
  Future<void> refreshHistory() async {
    try {
      final messages =
          await ref.read(chatRepositoryProvider).listMessages(channelId);
      state = AsyncData(_current.copyWith(messages: messages, clearError: true));
    } catch (e) {
      _setConnection(_current.connection, error: e.toString());
    }
  }

  void _teardown() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _socketSub?.cancel();
    _socket?.sink.close();
    _socket = null;
  }
}

final chatRoomProvider = AsyncNotifierProvider.family<ChatRoomNotifier,
    ChatRoomState, int>(
  ChatRoomNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Channel creation (STAFF: admin_ops / instructor)
/// ─────────────────────────────────────────────────────────────────────────

/// Whether the current user may create chat channels. Mirrors the backend RBAC
/// for `POST /chat/channels` (admin_ops & instructor only) so the "새 채팅방"
/// action is hidden from students and tech support.
final canCreateChannelProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserProvider)?.role;
  return role == AppRoles.adminOps || role == AppRoles.instructor;
});

/// Creates a channel via the repository, then refreshes every channel view so
/// the new room appears immediately:
///   - the flat list ([chatChannelListProvider]),
///   - the per-cohort cache for the target cohort, and
///   - the aggregated grouped view ([chatAggregatedChannelsProvider]).
///
/// Throws [ChatException] (clean Korean message) on failure so the caller can
/// surface it via SnackBar.
///
/// Takes a [WidgetRef] because it is driven from the create-channel dialog; it
/// both reads the repository and refreshes/invalidates the channel providers.
Future<ChatChannel> createChatChannel(
  WidgetRef ref, {
  required String name,
  required ChatChannelType type,
  required int cohortId,
  int? classId,
}) async {
  final channel = await ref.read(chatRepositoryProvider).createChannel(
        name: name,
        type: type.code,
        cohortId: cohortId,
        classId: classId,
      );

  // Refresh all channel views so the new room shows up without a manual reload.
  await ref.read(chatChannelListProvider.notifier).refresh();
  ref.invalidate(chatChannelsForCohortProvider(cohortId));
  ref.invalidate(chatAggregatedChannelsProvider);

  return channel;
}

/// ─────────────────────────────────────────────────────────────────────────
/// Attachment view URLs
/// ─────────────────────────────────────────────────────────────────────────

/// Resolves (and caches) a short-lived presigned GET URL for an attachment's
/// [fileKey] via `POST /files/download-url`.
///
/// Keyed by file key so a given attachment is fetched once and shared across
/// rebuilds (image widgets, file chips) rather than re-requesting on every
/// scroll. The URL is short-lived; the family is kept alive only as long as the
/// room is on screen, which is the intended freshness window.
final chatAttachmentUrlProvider =
    FutureProvider.family<String, String>((ref, fileKey) {
  return ref.watch(chatRepositoryProvider).getDownloadUrl(fileKey);
});
