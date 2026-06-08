import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/chat_bubble.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/ai_agent_model.dart';
import '../ai_agent_provider.dart';

/// Roles permitted to use the AI co-pilot (PRD-07 FR-07-21: students excluded).
const Set<String> _allowedRoles = {
  AppRoles.adminOps,
  AppRoles.instructor,
  AppRoles.techSupport,
};

/// AI co-pilot chat screen, mounted under each staff area
/// (`/ops/ai`, `/instructor/ai`, `/tech/ai`).
///
/// Layout: a scrolling transcript (user bubbles right / agent bubbles left with
/// the teal accent) over a fixed composer. Agent replies stream in token by
/// token via SSE. The screen reads the current role from [currentUserProvider]
/// and denies students a usable surface.
class AiAgentScreen extends ConsumerStatefulWidget {
  const AiAgentScreen({super.key});

  @override
  ConsumerState<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends ConsumerState<AiAgentScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    if (ref.read(aiChatProvider).isStreaming) return;
    _input.clear();
    _scrollToBottom();
    await ref.read(aiChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _allowedRoles.contains(role)
          ? _buildChat(context)
          : const _AccessDenied(),
    );
  }

  Widget _buildChat(BuildContext context) {
    final chat = ref.watch(aiChatProvider);

    // Auto-scroll as tokens stream in.
    ref.listen(aiChatProvider, (_, _) => _scrollToBottom());

    return Column(
      children: [
        _Header(
          isStreaming: chat.isStreaming,
          onReset: chat.isEmpty || chat.isStreaming
              ? null
              : () => ref.read(aiChatProvider.notifier).reset(),
        ),
        Expanded(
          child: chat.isEmpty
              ? _EmptyTranscript(onPromptTap: _send)
              : _Transcript(
                  controller: _scroll,
                  messages: chat.messages,
                  onRetry: () => ref.read(aiChatProvider.notifier).retryLast(),
                ),
        ),
        _Composer(
          controller: _input,
          enabled: !chat.isStreaming,
          onSend: _send,
        ),
      ],
    );
  }
}

/// Title bar with a "새 대화" reset action.
class _Header extends StatelessWidget {
  const _Header({required this.isStreaming, this.onReset});

  final bool isStreaming;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('AI 코파일럿', style: AppTypography.headlineSm),
          ),
          if (isStreaming) ...[
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '응답 생성 중...',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ] else
            AppButton(
              label: '새 대화',
              icon: Icons.add_comment_outlined,
              variant: AppButtonVariant.tertiary,
              onPressed: onReset,
            ),
        ],
      ),
    );
  }
}

/// Scrolling list of chat bubbles.
class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.controller,
    required this.messages,
    required this.onRetry,
  });

  final ScrollController controller;
  final List<AiMessage> messages;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _MessageTile(
        message: messages[index],
        onRetry: onRetry,
      ),
    );
  }
}

/// A single transcript row: the bubble plus, for streaming/error agent
/// messages, a typing indicator or retry affordance.
class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.onRetry});

  final AiMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    // While streaming with no text yet, show a subtle "생각 중" placeholder.
    final showThinking =
        message.streaming && message.content.trim().isEmpty;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ChatBubble(
          isUser: isUser,
          child: Builder(
            builder: (context) {
              if (showThinking) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '생각 중...',
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                );
              }
              return Text(
                message.content,
                style: AppTypography.bodyMd.copyWith(
                  color: isUser
                      ? AppColors.onPrimary
                      : (message.isError
                          ? AppColors.error
                          : AppColors.onSurface),
                ),
              );
            },
          ),
        ),
        if (message.toolsUsed.isNotEmpty && !message.streaming) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '사용한 도구: ${message.toolsUsed.join(', ')}',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
        if (message.isError && !message.streaming) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '다시 시도',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}

/// First-run state: guidance + sample-prompt chips sourced from the tool list.
class _EmptyTranscript extends ConsumerWidget {
  const _EmptyTranscript({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(aiToolsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            icon: Icons.auto_awesome_rounded,
            title: '무엇을 도와드릴까요?',
            description: '출결·과제·수강생 데이터를 자연어로 물어보세요.\n예: "이번 달 결석 3회 이상 학생 목록"',
          ),
          const SizedBox(height: AppSpacing.lg),
          tools.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) => _SamplePrompts(
              tools: items,
              onTap: onPromptTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable sample-prompt chips derived from the whitelisted tools.
class _SamplePrompts extends StatelessWidget {
  const _SamplePrompts({required this.tools, required this.onTap});

  final List<AiTool> tools;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tool in tools)
          ActionChip(
            avatar: const Icon(Icons.bolt_outlined,
                size: 16, color: AppColors.primary),
            label: Text(tool.description),
            backgroundColor: AppColors.surfaceContainerLow,
            side: const BorderSide(color: AppColors.outlineVariant),
            labelStyle: AppTypography.bodySm,
            onPressed: () => onTap(tool.description),
          ),
      ],
    );
  }
}

/// Bottom message composer. Disabled while a response streams in to prevent
/// duplicate submission.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? onSend : null,
                decoration: const InputDecoration(
                  hintText: '질문을 입력하세요...',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: enabled ? () => onSend(controller.text) : null,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Permission-denied surface for roles outside [_allowedRoles] (students).
class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const ErrorView(message: '접근 권한이 없습니다.');
  }
}
