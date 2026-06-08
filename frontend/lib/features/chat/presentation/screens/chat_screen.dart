import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cohort_filter.dart';
import '../../../../core/file_pick.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/utils/file_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/chat_bubble.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_model.dart';
import '../chat_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Channel list — `/chat`
/// ─────────────────────────────────────────────────────────────────────────

/// Lists the live chat channels for the user's cohort. Tapping a channel opens
/// its room. When exactly one channel exists this still renders a list (the
/// route layer decides whether to deep-link straight into a room).
///
/// STAFF viewing "기수 전체" ([chatStaffAllCohortsProvider]) get an aggregated
/// view: channels are fetched per cohort and rendered grouped under a cohort
/// section header ("1기"). Students, and staff with a specific cohort selected,
/// get a single flat list.
class ChatChannelListScreen extends ConsumerWidget {
  const ChatChannelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaffAllCohorts = ref.watch(chatStaffAllCohortsProvider);
    final canCreate = ref.watch(canCreateChannelProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      // Channel creation is staff-only (admin_ops / instructor); students never
      // see the action.
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          if (canCreate) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AppButton(
                label: '새 채팅방',
                icon: Icons.add_comment_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () => _openCreateChannelDialog(context, ref),
              ),
            ),
          ],
        ],
      ),
      body: isStaffAllCohorts
          ? const _AggregatedChannelList()
          : const _FlatChannelList(),
    );
  }

  Future<void> _openCreateChannelDialog(
      BuildContext context, WidgetRef ref) async {
    final created = await showDialog<ChatChannel>(
      context: context,
      builder: (_) => const _CreateChannelDialog(),
    );
    if (created != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'${created.name}' 채팅방을 만들었습니다.")),
      );
    }
  }
}

/// Dialog for creating a channel (staff only). Collects a name, a channel type
/// (기수 / 수업 / 자유), and a target cohort. The cohort defaults to the globally
/// selected cohort; when none is selected the user must pick one from the
/// role-scoped [cohortOptionsProvider].
class _CreateChannelDialog extends ConsumerStatefulWidget {
  const _CreateChannelDialog();

  @override
  ConsumerState<_CreateChannelDialog> createState() =>
      _CreateChannelDialogState();
}

class _CreateChannelDialogState extends ConsumerState<_CreateChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  ChatChannelType _type = ChatChannelType.cohort;
  int? _cohortId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Default to the globally-selected cohort (may be null = "기수 전체").
    _cohortId = ref.read(selectedCohortProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cohortId = _cohortId;
    if (cohortId == null) return; // validator on the picker guards this too.

    setState(() => _submitting = true);
    try {
      final channel = await createChatChannel(
        ref,
        name: _nameController.text.trim(),
        type: _type,
        cohortId: cohortId,
      );
      if (mounted) Navigator.of(context).pop(channel);
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채팅방을 만들지 못했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cohortsAsync = ref.watch(cohortOptionsProvider);

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      title: const Text('새 채팅방'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                enabled: !_submitting,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: '채팅방 이름',
                  hintText: '예: 1기 자유 대화방',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '채팅방 이름을 입력해주세요.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ChatChannelType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '대화방 유형'),
                items: [
                  for (final t in ChatChannelType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: AppSpacing.md),
              cohortsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: LinearProgressIndicator(),
                ),
                error: (_, _) => Text(
                  '기수 목록을 불러오지 못했습니다.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onErrorContainer),
                ),
                data: (cohorts) {
                  // Keep the default only if it is a valid option.
                  final valid = cohorts.any((c) => c.id == _cohortId);
                  final value = valid ? _cohortId : null;
                  return DropdownButtonFormField<int>(
                    initialValue: value,
                    decoration: const InputDecoration(labelText: '대상 기수'),
                    items: [
                      for (final c in cohorts)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _cohortId = v),
                    validator: (v) => v == null ? '대상 기수를 선택해주세요.' : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: '취소',
          variant: AppButtonVariant.tertiary,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: '만들기',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}

/// Flat, single-cohort channel list — students, or staff with a specific cohort
/// selected. Backed by [chatChannelListProvider].
class _FlatChannelList extends ConsumerWidget {
  const _FlatChannelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(chatChannelListProvider);

    return channels.when(
      loading: () => const LoadingView(message: '채팅 채널을 불러오는 중입니다'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.read(chatChannelListProvider.notifier).refresh(),
      ),
      data: (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.forum_outlined,
              title: '참여 가능한 채팅이 없습니다',
              description: '수업 라이브 채팅이 개설되면 이곳에 표시됩니다.',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(chatChannelListProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _ChannelTile(channel: list[i]),
              ),
            ),
    );
  }
}

/// Aggregated, grouped-by-cohort channel list for STAFF at "기수 전체". Renders a
/// cohort section header per group followed by that cohort's channel rows.
/// Backed by [chatAggregatedChannelsProvider].
class _AggregatedChannelList extends ConsumerWidget {
  const _AggregatedChannelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(chatAggregatedChannelsProvider);

    return groupsAsync.when(
      loading: () => const LoadingView(message: '채팅 채널을 불러오는 중입니다'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(chatAggregatedChannelsProvider),
      ),
      data: (groups) => groups.isEmpty
          ? const EmptyState(
              icon: Icons.forum_outlined,
              title: '참여 가능한 채팅이 없습니다',
              description: '수업 라이브 채팅이 개설되면 이곳에 표시됩니다.',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(chatAggregatedChannelsProvider);
                await ref.read(chatAggregatedChannelsProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: groups.length,
                itemBuilder: (context, i) =>
                    _CohortGroupSection(group: groups[i]),
              ),
            ),
    );
  }
}

/// One cohort's section: a header chip ("1기") + that cohort's channel rows.
class _CohortGroupSection extends StatelessWidget {
  const _CohortGroupSection({required this.group});

  final ChatCohortGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              StatusChip(
                label: group.cohort.name,
                tone: StatusTone.info,
                icon: Icons.groups_outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '채널 ${group.channels.length}개',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final channel in group.channels) ...[
          _ChannelTile(channel: channel),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final ChatChannel channel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.go('/chat/${channel.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(channel.name, style: AppTypography.headlineSm),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Chat room — `/chat/:channelId`
/// ─────────────────────────────────────────────────────────────────────────

/// Live chat room: message list (own messages right-aligned), a send box, and
/// a connection-status banner with a manual reconnect affordance.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.channelId, this.channelName});

  final int channelId;
  final String? channelName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  /// True while attachments are being uploaded (presign + PUT), so the composer
  /// can show a spinner and block duplicate submissions.
  bool _uploading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _onSend(int currentUserId) {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    ref
        .read(chatRoomProvider(widget.channelId).notifier)
        .send(text, currentUserId: currentUserId);
    _inputController.clear();
    _scrollToBottom();
  }

  /// Opens the file picker (images + files), uploads the selection, and sends
  /// it together with any typed text. Oversized files are rejected up front.
  Future<void> _onAttach(int currentUserId) async {
    if (_uploading) return;

    final picked = await pickFiles(multiple: true);
    if (picked.isEmpty || !mounted) return;

    final tooBig = picked.where((f) => !FileUtils.isWithinSizeLimit(f.size));
    if (tooBig.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '파일 크기는 ${FileUtils.humanSize(FileUtils.maxUploadBytes)}를 넘을 수 없습니다.',
          ),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    final text = _inputController.text;
    final ok = await ref
        .read(chatRoomProvider(widget.channelId).notifier)
        .uploadAndSend(
          files: [
            for (final f in picked)
              (fileName: f.fileName, contentType: f.contentType, bytes: f.bytes),
          ],
          currentUserId: currentUserId,
          text: text,
        );

    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) {
      _inputController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = chatRoomProvider(widget.channelId);
    final roomAsync = ref.watch(provider);
    final currentUser = ref.watch(currentUserProvider);
    final myId = currentUser?.id ?? -1;

    // Keep the list pinned to the newest message as it grows.
    ref.listen(provider, (prev, next) {
      final prevLen = prev?.value?.messages.length ?? 0;
      final nextLen = next.value?.messages.length ?? 0;
      if (nextLen > prevLen) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.channelName ?? '채팅'),
      ),
      body: roomAsync.when(
        loading: () => const LoadingView(message: '대화를 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(provider),
        ),
        data: (room) => Column(
          children: [
            _ConnectionBanner(
              status: room.connection,
              error: room.error,
              onReconnect: () =>
                  ref.read(provider.notifier).reconnect(),
            ),
            Expanded(
              child: room.messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '아직 메시지가 없습니다',
                      description: '첫 메시지를 보내 대화를 시작해보세요.',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: room.messages.length,
                      itemBuilder: (context, i) {
                        final msg = room.messages[i];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _MessageRow(
                            message: msg,
                            isMine: msg.senderId == myId,
                          ),
                        );
                      },
                    ),
            ),
            _ChatInputBar(
              controller: _inputController,
              enabled: room.connection == ChatConnectionStatus.connected &&
                  !_uploading,
              uploading: _uploading,
              onSend: () => _onSend(myId),
              onAttach: () => _onAttach(myId),
            ),
          ],
        ),
      ),
    );
  }
}

/// Connection status indicator. Hidden when connected; shows "연결 중" while the
/// socket is handshaking and a "재연결" action when disconnected.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.status,
    required this.onReconnect,
    this.error,
  });

  final ChatConnectionStatus status;
  final VoidCallback onReconnect;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (status == ChatConnectionStatus.connected && error == null) {
      return const SizedBox.shrink();
    }

    final bool disconnected = status == ChatConnectionStatus.disconnected;
    final Color bg =
        disconnected ? AppColors.errorContainer : AppColors.surfaceContainerHigh;
    final Color fg =
        disconnected ? AppColors.onErrorContainer : AppColors.onSurfaceVariant;
    final String label = error ??
        (status == ChatConnectionStatus.connecting ? '연결 중…' : '연결이 끊어졌습니다');

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (status == ChatConnectionStatus.connecting)
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            Icon(Icons.wifi_off_rounded, size: 16, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(color: fg),
            ),
          ),
          if (disconnected)
            TextButton(
              onPressed: onReconnect,
              child: const Text('재연결'),
            ),
        ],
      ),
    );
  }
}

/// A single message line: an optional sender label, the bubble (text and/or
/// attachments), and a small timestamp / sending hint.
///
/// Own messages are right-aligned and unlabelled; other people's messages are
/// left-aligned and show the sender's name above the bubble.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final meta = message.pending
        ? '보내는 중…'
        : DateFormatter.time(message.createdAt);

    final hasText = message.content.trim().isNotEmpty;

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Sender name for other people's messages only.
        if (!isMine && message.senderName.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Text(
              message.senderName,
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Opacity(
          opacity: message.pending ? 0.6 : 1,
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (hasText) ChatBubble.text(message.content, isUser: isMine),
              if (message.hasAttachments) ...[
                if (hasText) const SizedBox(height: AppSpacing.xs),
                for (final att in message.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _AttachmentView(attachment: att, isMine: isMine),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          meta,
          style:
              AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Renders one attachment. Image content types are previewed inline (tap to
/// open full size); everything else is shown as a tappable file chip.
///
/// The presigned view URL is resolved via [chatAttachmentUrlProvider], which
/// caches by file key so it is not re-fetched on every rebuild/scroll.
class _AttachmentView extends ConsumerWidget {
  const _AttachmentView({required this.attachment, required this.isMine});

  final ChatAttachment attachment;
  final bool isMine;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final url =
          await ref.read(chatAttachmentUrlProvider(attachment.fileKey).future);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _AttachmentPreviewDialog(
          attachment: attachment,
          url: url,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 열지 못했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachment.isImage) {
      final urlAsync = ref.watch(chatAttachmentUrlProvider(attachment.fileKey));
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.6,
          maxHeight: 220,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: urlAsync.when(
            loading: () => const _ImagePlaceholder(),
            error: (_, _) => const _ImagePlaceholder(failed: true),
            data: (url) => InkWell(
              onTap: () => _open(context, ref),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const _ImagePlaceholder(failed: true),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _ImagePlaceholder(),
              ),
            ),
          ),
        ),
      );
    }

    // Non-image → file chip.
    return Material(
      color: isMine
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName.isEmpty
                          ? '첨부파일'
                          : attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm,
                    ),
                    Text(
                      FileUtils.extension(attachment.fileName).toUpperCase(),
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.download_rounded,
                  size: 18, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 120,
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: failed
          ? const Icon(Icons.broken_image_outlined, color: AppColors.outline)
          : const SizedBox(
              height: 20,
              width: 20,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
    );
  }
}

/// Full-size attachment preview. Shows the image (for image types) plus the
/// file name; tapping outside or "닫기" dismisses it.
class _AttachmentPreviewDialog extends StatelessWidget {
  const _AttachmentPreviewDialog({required this.attachment, required this.url});

  final ChatAttachment attachment;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              attachment.fileName.isEmpty ? '첨부파일' : attachment.fileName,
              style: AppTypography.headlineSm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            if (attachment.isImage)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('이미지를 불러오지 못했습니다.'),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '이 파일은 미리 볼 수 없습니다. 아래 링크로 열어주세요.',
                        style: AppTypography.bodySm,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              url,
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: '닫기',
                variant: AppButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Themed input row: attach button + text field + send button. Disabled while
/// the socket is not connected or an upload is in flight.
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.uploading,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final String hint = uploading
        ? '파일을 업로드하는 중입니다…'
        : (enabled ? '메시지를 입력하세요' : '연결 중입니다…');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(color: AppColors.outlineVariant, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach (image / file). Uses the picker → presign → PUT pipeline.
            IconButton(
              tooltip: '파일 첨부',
              onPressed: enabled ? onAttach : null,
              icon: uploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.attach_file_rounded),
              color: AppColors.primary,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (enabled) onSend();
                },
                decoration: InputDecoration(hintText: hint),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
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
