import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/file_pick.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/file_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/board_model.dart';
import '../board_provider.dart';
import '../community_paths.dart';

/// Compose / edit screen (`/student/community/write`,
/// `/student/community/posts/:id/edit`).
///
/// Receives the target [board] (passed via go_router `extra`). When [editPost]
/// is non-null the screen runs in edit mode: it seeds the form from the post,
/// hides the anonymous / private toggles (those flags are immutable after
/// creation), and PATCHes on submit. Otherwise it composes a new post, showing
/// the anonymous / private toggles gated on the board flags. On success it pops
/// back.
class PostWriteScreen extends ConsumerStatefulWidget {
  const PostWriteScreen({super.key, required this.board, this.editPost});

  final Board board;
  final Post? editPost;

  @override
  ConsumerState<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends ConsumerState<PostWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  int get _boardId => widget.board.id;
  bool get _isEditing => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(postFormProvider(_boardId).notifier);
    if (widget.editPost != null) {
      notifier.loadForEdit(widget.editPost!);
      _titleController.text = widget.editPost!.title;
      _contentController.text = widget.editPost!.content;
    }
    _titleController.addListener(() => notifier.setTitle(_titleController.text));
    _contentController
        .addListener(() => notifier.setContent(_contentController.text));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickFiles();
      if (picked.isEmpty) return; // user cancelled
      final file = picked.first;
      if (!FileUtils.isWithinSizeLimit(file.size)) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
              '${file.fileName}: 최대 '
              '${FileUtils.humanSize(FileUtils.maxUploadBytes)}까지 첨부할 수 있습니다.',
            ),
          ));
        return;
      }
      await ref.read(postFormProvider(_boardId).notifier).uploadAttachment(
            fileName: file.fileName,
            contentType: file.contentType,
            bytes: file.bytes,
          );
      if (!mounted) return;
      final error = ref.read(postFormProvider(_boardId)).error;
      if (error != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('파일을 불러오지 못했습니다.')));
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref.read(postFormProvider(_boardId).notifier).submit();
    final state = ref.read(postFormProvider(_boardId));
    if (!mounted) return;
    if (state.created != null) {
      // Refresh the board's list so the change shows immediately.
      ref
          .read(postListProvider(PostListArgs(boardId: _boardId)).notifier)
          .refresh();
      if (_isEditing) {
        // Refresh the detail view so the edited body is re-fetched.
        ref.invalidate(postDetailProvider(state.created!.id));
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_isEditing ? '게시글을 수정했습니다.' : '게시글을 등록했습니다.')),
        );
      context.canPop()
          ? context.pop()
          : context.go(CommunityPaths.of(context).root);
    } else if (state.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(postFormProvider(_boardId));
    final notifier = ref.read(postFormProvider(_boardId).notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WriteHeader(
              boardName: widget.board.name,
              isEditing: _isEditing,
              onClose: () => context.canPop()
                  ? context.pop()
                  : context.go(CommunityPaths.of(context).root),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '제목',
                            hintText: '제목을 입력하세요',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _contentController,
                          minLines: 8,
                          maxLines: 16,
                          decoration: const InputDecoration(
                            labelText: '내용',
                            hintText: '내용을 입력하세요',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Anonymity / privacy are fixed at creation, so the options
                  // card is only shown when composing a new post.
                  if (!_isEditing) ...[
                    const SizedBox(height: AppSpacing.md),
                    _OptionsCard(
                      board: widget.board,
                      form: form,
                      onAnonymous: notifier.setAnonymous,
                      onPrivate: notifier.setPrivate,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _AttachmentsCard(
                    form: form,
                    onRemove: notifier.removeAttachment,
                    onPick: form.isUploading ? null : _pickAttachment,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: _isEditing ? '저장' : '등록',
                    icon: Icons.check_rounded,
                    expand: true,
                    loading: form.isSubmitting,
                    onPressed: form.isValid && !form.isBusy ? _submit : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteHeader extends StatelessWidget {
  const _WriteHeader({
    required this.boardName,
    required this.onClose,
    this.isEditing = false,
  });

  final String boardName;
  final VoidCallback onClose;
  final bool isEditing;

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
            icon: const Icon(Icons.close_rounded),
            tooltip: '닫기',
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              isEditing ? '$boardName · 글 수정' : '$boardName · 글쓰기',
              style: AppTypography.headlineSm,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.board,
    required this.form,
    required this.onAnonymous,
    required this.onPrivate,
  });

  final Board board;
  final PostFormState form;
  final ValueChanged<bool> onAnonymous;
  final ValueChanged<bool> onPrivate;

  @override
  Widget build(BuildContext context) {
    if (!board.allowAnonymous && !board.allowPrivatePost) {
      return const SizedBox.shrink();
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          if (board.allowAnonymous)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primary,
              value: form.isAnonymous,
              onChanged: onAnonymous,
              title: Text('익명으로 작성', style: AppTypography.bodyMd),
              subtitle: Text(
                '작성자 이름이 "익명"으로 표시됩니다.',
                style: AppTypography.labelSm,
              ),
            ),
          if (board.allowPrivatePost)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primary,
              value: form.isPrivate,
              onChanged: onPrivate,
              title: Text('비밀글로 작성', style: AppTypography.bodyMd),
              subtitle: Text(
                '작성자와 운영팀만 열람할 수 있습니다.',
                style: AppTypography.labelSm,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({
    required this.form,
    required this.onRemove,
    this.onPick,
  });

  final PostFormState form;
  final ValueChanged<String> onRemove;

  /// Opens the file picker; null while an upload is in flight.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file_rounded,
                  size: 18, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Text('첨부파일', style: AppTypography.labelMd),
              if (form.isUploading) ...[
                const SizedBox(width: AppSpacing.sm),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          if (form.attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '첨부된 파일이 없습니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            )
          else
            for (final a in form.attachments)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 16, color: AppColors.outline),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        a.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm,
                      ),
                    ),
                    if (a.size != null)
                      Text(
                        FileUtils.humanSize(a.size!),
                        style: AppTypography.labelSm,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      tooltip: '삭제',
                      onPressed: () => onRemove(a.fileKey),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: '파일 첨부',
            icon: Icons.attach_file_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onPick,
          ),
        ],
      ),
    );
  }
}
