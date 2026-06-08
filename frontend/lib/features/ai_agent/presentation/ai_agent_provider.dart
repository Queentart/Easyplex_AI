import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_agent_repository.dart';
import '../domain/ai_agent_model.dart';

/// Immutable snapshot of the co-pilot conversation.
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.sessionId,
  });

  /// The full transcript, oldest first. The last entry may be a still-streaming
  /// agent message (its [AiMessage.streaming] flag is true).
  final List<AiMessage> messages;

  /// True while an agent response is being received (input/send disabled).
  final bool isStreaming;

  /// Conversation session id, kept for follow-up context (server-managed).
  final String? sessionId;

  bool get isEmpty => messages.isEmpty;

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? isStreaming,
    String? sessionId,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

/// Drives the AI co-pilot transcript.
///
/// On [send] it appends the user message plus an empty streaming agent bubble,
/// then consumes the repository's [AiAgentRepository.queryStream] SSE stream,
/// appending each token delta to the agent bubble live. A 429 rate-limit (or
/// any other failure) is surfaced cleanly as an error agent message rather than
/// throwing — the UI stays usable. [reset] starts a fresh conversation.
class AiChatNotifier extends Notifier<AiChatState> {
  StreamSubscription<String>? _subscription;

  @override
  AiChatState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const AiChatState();
  }

  /// Sends [prompt] and streams the agent reply. No-ops on empty input or while
  /// a response is already streaming (prevents duplicate submission).
  Future<void> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || state.isStreaming) return;

    // Append the user message + a placeholder streaming agent bubble.
    final base = [
      ...state.messages,
      AiMessage.user(text),
      AiMessage.agent('', streaming: true),
    ];
    state = state.copyWith(messages: base, isStreaming: true);
    final agentIndex = base.length - 1;

    final repo = ref.read(aiAgentRepositoryProvider);
    final completer = Completer<void>();
    final buffer = StringBuffer();

    await _subscription?.cancel();
    _subscription = repo
        .queryStream(text, sessionId: state.sessionId)
        .listen(
      (delta) {
        buffer.write(delta);
        _replaceAgent(
          agentIndex,
          (m) => m.copyWith(content: buffer.toString(), streaming: true),
        );
      },
      onError: (Object e) {
        _finishWithError(agentIndex, buffer, e);
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        // If nothing streamed (e.g. immediate disconnect), show a fallback.
        final finalText = buffer.toString().trim().isEmpty
            ? '응답을 받지 못했습니다. 다시 시도해주세요.'
            : buffer.toString().trimRight();
        _replaceAgent(
          agentIndex,
          (m) => m.copyWith(content: finalText, streaming: false),
        );
        state = state.copyWith(isStreaming: false);
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Retries the most recent user prompt (used after a transient error).
  Future<void> retryLast() async {
    final lastUser = state.messages.lastWhere(
      (m) => m.isUser,
      orElse: () => AiMessage.user(''),
    );
    if (lastUser.content.trim().isEmpty) return;

    // Drop the trailing error agent bubble (and the user message we re-send)
    // so the conversation does not duplicate entries.
    final trimmed = [...state.messages];
    if (trimmed.isNotEmpty && !trimmed.last.isUser) trimmed.removeLast();
    if (trimmed.isNotEmpty && trimmed.last.isUser) trimmed.removeLast();
    state = state.copyWith(messages: trimmed);

    await send(lastUser.content);
  }

  /// Clears the transcript and starts a new conversation context.
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    state = const AiChatState();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _replaceAgent(int index, AiMessage Function(AiMessage) update) {
    final list = [...state.messages];
    if (index < 0 || index >= list.length) return;
    list[index] = update(list[index]);
    state = state.copyWith(messages: list);
  }

  void _finishWithError(int index, StringBuffer buffer, Object error) {
    final message = error is AiAgentException
        ? error.message
        : '응답을 받지 못했습니다. 다시 시도해주세요.';
    final partial = buffer.toString().trimRight();
    // Keep any partial answer received before the error, then append the notice.
    final body = partial.isEmpty ? message : '$partial\n\n$message';
    _replaceAgent(
      index,
      (m) => m.copyWith(content: body, streaming: false, isError: true),
    );
    state = state.copyWith(isStreaming: false);
  }
}

/// The co-pilot conversation provider.
final aiChatProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);

/// Loads the whitelisted tools, surfaced as sample-prompt hints on the empty
/// state. Auto-disposed so it refetches when the screen is re-entered.
final aiToolsProvider = FutureProvider.autoDispose<List<AiTool>>((ref) {
  return ref.read(aiAgentRepositoryProvider).tools();
});
