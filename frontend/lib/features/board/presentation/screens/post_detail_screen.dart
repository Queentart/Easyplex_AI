import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/utils/file_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/board_repository.dart';
import '../../domain/board_model.dart';
import '../board_provider.dart';
import '../community_paths.dart';

/// Post detail screen (`/student/community/posts/:id`): the post body, its
/// attachments, and the comment thread with an inline composer.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHeader(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(CommunityPaths.of(context).root),
            ),
            Expanded(
              child: postAsync.when(
                loading: () => const LoadingView(message: '게시글을 불러오는 중입니다'),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(postDetailProvider(postId)),
                ),
                data: (post) => _PostBody(post: post),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: '뒤로',
            onPressed: onBack,
          ),
          Text('게시글', style: AppTypography.headlineSm),
        ],
      ),
    );
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post});

  final Post post;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '게시글을 삭제하시겠습니까?',
      message: '삭제한 게시글은 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(boardRepositoryProvider).deletePost(post.id);
      // Reflect the removal in the originating board's list.
      ref
          .read(postListProvider(PostListArgs(boardId: post.boardId)).notifier)
          .removeLocally(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('게시글을 삭제했습니다.')));
        context.canPop()
            ? context.pop()
            : context.go(CommunityPaths.of(context).root);
      }
    } on BoardException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Opens the write screen in edit mode for this post (author · admin).
  void _edit(BuildContext context) {
    context.push(CommunityPaths.of(context).postEdit(post.id), extra: post);
  }

  /// Toggles the pinned (공지 고정) state (운영팀 · 강사) and surfaces the result.
  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(postManagerProvider).togglePin(post);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(post.isPinned ? '고정을 해제했습니다.' : '게시글을 고정했습니다.'),
            ),
          );
      }
    } on BoardException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdminOps = currentUser?.role == 'admin_ops';
    final isInstructor = currentUser?.role == 'instructor';
    final canManage = post.isAuthoredBy(currentUser?.id) || isAdminOps;
    final canPin = isAdminOps || isInstructor;
    // Only operations staff may de-anonymize, and only an anonymous post has an
    // identity to reveal.
    final canRevealAuthor = isAdminOps && post.isAnonymous;
    final commentsAsync = ref.watch(commentListProvider(post.id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.isPinned) ...[
                    const StatusChip(
                      label: '공지',
                      tone: StatusTone.info,
                      icon: Icons.push_pin_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (post.isPrivate) ...[
                    const StatusChip(
                      label: '비밀',
                      tone: StatusTone.neutral,
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(post.title, style: AppTypography.headlineMd),
                  ),
                  if (canPin)
                    IconButton(
                      icon: Icon(
                        post.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                      color: post.isPinned ? AppColors.primary : null,
                      tooltip: post.isPinned ? '고정 해제' : '고정',
                      onPressed: () => _togglePin(context, ref),
                    ),
                  if (canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: '관리',
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _edit(context);
                          case 'delete':
                            _delete(context, ref);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('수정'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded,
                                color: AppColors.error),
                            title: Text('삭제'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 16, color: AppColors.outline),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    post.isAnonymous ? '익명' : '작성자 #${post.authorId}',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    DateFormatter.dateTime(post.createdAt),
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              if (canRevealAuthor) ...[
                const SizedBox(height: AppSpacing.sm),
                _AuthorRevealButton(postId: post.id),
              ],
              const Divider(height: AppSpacing.lg * 2),
              Text(post.content, style: AppTypography.bodyMd),
              if (post.attachments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('첨부파일', style: AppTypography.labelMd),
                const SizedBox(height: AppSpacing.sm),
                for (final a in post.attachments) _AttachmentRow(attachment: a),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '댓글',
          style: AppTypography.headlineSm,
        ),
        const SizedBox(height: AppSpacing.sm),
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LoadingView(),
          ),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.read(commentListProvider(post.id).notifier).refresh(),
          ),
          data: (comments) => comments.isEmpty
              ? const EmptyState(
                  icon: Icons.mode_comment_outlined,
                  title: '첫 댓글을 남겨보세요',
                )
              : Column(
                  children: [
                    for (final c in comments)
                      _CommentTile(
                        comment: c,
                        canManage: c.isAuthoredBy(currentUser?.id) ||
                            currentUser?.role == 'admin_ops',
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CommentComposer(
          postId: post.id,
          allowAnonymous: post.isAnonymous,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 16, color: AppColors.outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              attachment.fileName,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm,
            ),
          ),
          if (attachment.size != null)
            Text(
              FileUtils.humanSize(attachment.size!),
              style: AppTypography.labelSm,
            ),
        ],
      ),
    );
  }
}

/// Operator-only control that reveals an anonymous post's real author through
/// the audited `author-identity` endpoint. Requires a non-empty reason, warns
/// that the action is logged, then shows the revealed name/id inline.
class _AuthorRevealButton extends ConsumerStatefulWidget {
  const _AuthorRevealButton({required this.postId});

  final int postId;

  @override
  ConsumerState<_AuthorRevealButton> createState() =>
      _AuthorRevealButtonState();
}

class _AuthorRevealButtonState extends ConsumerState<_AuthorRevealButton> {
  AuthorIdentity? _identity;
  bool _loading = false;

  Future<void> _reveal() async {
    final reason = await _promptReason(context);
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final identity = await ref
          .read(postManagerProvider)
          .revealAuthor(widget.postId, reason.trim());
      if (mounted) setState(() => _identity = identity);
    } on BoardException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_identity != null) {
      final id = _identity!;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.onWarningContainer),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '작성자 확인 결과',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onWarningContainer),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${id.authorName} (#${id.authorId})',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onWarningContainer),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '이 조회는 감사 로그에 기록되었습니다.',
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onWarningContainer),
            ),
          ],
        ),
      );
    }

    return AppButton(
      label: '작성자 확인',
      icon: Icons.visibility_outlined,
      variant: AppButtonVariant.secondary,
      loading: _loading,
      onPressed: _reveal,
    );
  }
}

/// Asks the operator for the reason behind an anonymity reveal, warning that
/// the action is audited. Returns the reason, or null when cancelled.
Future<String?> _promptReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('작성자 확인', style: AppTypography.headlineSm),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '익명 게시글의 작성자를 확인합니다. 이 조회는 감사 로그에 기록되며, '
                '확인 사유를 반드시 입력해야 합니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '확인 사유',
                  hintText: '예: 신고된 게시글 조사',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: '취소',
                    variant: AppButtonVariant.tertiary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: '확인',
                    icon: Icons.visibility_outlined,
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      Navigator.of(context).pop(text);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({required this.comment, required this.canManage});

  final Comment comment;
  final bool canManage;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  bool _editing = false;
  bool _saving = false;
  TextEditingController? _controller;

  Comment get _comment => widget.comment;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _controller = TextEditingController(text: _comment.content);
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _controller?.dispose();
      _controller = null;
    });
  }

  Future<void> _saveEdit() async {
    final text = _controller?.text.trim() ?? '';
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(commentListProvider(_comment.postId ?? 0).notifier)
          .edit(_comment.id, text);
      if (mounted) _cancelEdit();
    } on BoardException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: '댓글을 삭제하시겠습니까?',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref
          .read(commentListProvider(_comment.postId ?? 0).notifier)
          .remove(_comment.id);
    } on BoardException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _comment.isAnonymous ? '익명' : '작성자 #${_comment.authorId}',
                style: AppTypography.labelMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                DateFormatter.relative(_comment.createdAt),
                style: AppTypography.labelSm,
              ),
              const Spacer(),
              if (widget.canManage && !_editing) ...[
                InkWell(
                  onTap: _startEdit,
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.outline),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: _delete,
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.outline),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_editing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '댓글을 수정하세요'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: '취소',
                      variant: AppButtonVariant.tertiary,
                      onPressed: _saving ? null : _cancelEdit,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: '저장',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saveEdit,
                    ),
                  ],
                ),
              ],
            )
          else
            Text(_comment.content, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}

class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({required this.postId, required this.allowAnonymous});

  final int postId;
  final bool allowAnonymous;

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _controller = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(commentListProvider(widget.postId).notifier).add(
            content: text,
            isAnonymous: _anonymous,
          );
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } on BoardException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (widget.allowAnonymous)
                Row(
                  children: [
                    Switch(
                      value: _anonymous,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setState(() => _anonymous = v),
                    ),
                    Text('익명', style: AppTypography.bodySm),
                  ],
                ),
              const Spacer(),
              AppButton(
                label: '등록',
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
