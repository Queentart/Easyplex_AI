import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_labels.dart';
import '../../../../core/cohort_filter.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/list_header.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/board_repository.dart';
import '../../domain/board_model.dart';
import '../board_provider.dart';

/// Board management screen (`/ops/boards`, `/instructor/boards`).
///
/// Lets the operations team / instructors create, edit and delete boards.
/// Operations-team layouts are PC/tablet-first (data table); on narrow widths
/// it falls back to a card list. The whole screen is role-gated — students
/// who somehow reach it see an access notice rather than the controls.
class BoardManagementScreen extends ConsumerWidget {
  const BoardManagementScreen({super.key});

  bool _canManage(String? role) => role == 'admin_ops' || role == 'instructor';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;

    if (!_canManage(role)) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: '접근 권한이 없습니다',
            description: '게시판 관리는 운영팀과 강사만 이용할 수 있습니다.',
          ),
        ),
      );
    }

    final groupsAsync = ref.watch(groupedBoardManagementProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListHeader(
              title: AppLabels.communityManagement,
              action: AppButton(
                label: '게시판 개설',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () => _openForm(context, ref),
              ),
            ),
            Expanded(
              child: groupsAsync.when(
                loading: () => const LoadingView(message: '게시판을 불러오는 중입니다'),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(groupedBoardManagementProvider),
                ),
                data: (groups) {
                  final hasBoards = groups.any((g) => g.boards.isNotEmpty);
                  if (!hasBoards) {
                    // Single create button lives in the header — the empty
                    // state shows guidance text without a second button.
                    return const EmptyState(
                      icon: Icons.dashboard_customize_outlined,
                      title: '개설된 게시판이 없습니다',
                      description: '상단의 "게시판 개설" 버튼으로 새 게시판을 만들 수 있습니다.',
                    );
                  }
                  // Show cohort group headers only in the aggregated
                  // ("기수 전체") view; a single unlabeled group is rendered flat.
                  final grouped = groups.length > 1 ||
                      (groups.length == 1 && groups.first.title.isNotEmpty);
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(groupedBoardManagementProvider),
                    child: ResponsiveLayout(
                      mobile: (_) =>
                          _BoardCardList(groups: groups, grouped: grouped),
                      tablet: (_) =>
                          _BoardTable(groups: groups, grouped: grouped),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Board? board}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BoardFormDialog(board: board),
    );
  }
}

/// A small cohort section header rendered above each group's boards in the
/// aggregated ("기수 전체") management view.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final BoardGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          StatusChip(
            label: group.title,
            tone: group.isInstitution ? StatusTone.info : StatusTone.neutral,
            icon: group.isInstitution
                ? Icons.groups_outlined
                : Icons.school_outlined,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '게시판 ${group.boards.length}개',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Desktop / tablet table ────────────────────────────────────────────────

class _BoardTable extends ConsumerWidget {
  const _BoardTable({required this.groups, required this.grouped});

  final List<BoardGroup> groups;

  /// When true, each non-empty group is preceded by a cohort section header.
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final group in groups)
          if (group.boards.isNotEmpty) ...[
            if (grouped) _GroupHeader(group: group),
            AppDataTable(
              columns: const ['이름', '유형', '옵션', '공개범위', '관리'],
              columnFlex: const [3, 2, 3, 2, 2],
              rows: [
                for (final b in group.boards)
                  AppTableRow(
                    cells: [
                      Text(b.name, style: AppTypography.bodyMd),
                      Text(b.type),
                      _OptionBadges(board: b),
                      Text(_visibilityLabel(b.visibility)),
                      _RowActions(board: b),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: '수정',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _BoardFormDialog(board: board),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: AppColors.error,
          tooltip: '삭제',
          onPressed: () => _confirmDelete(context, ref, board),
        ),
      ],
    );
  }
}

// ── Mobile card list ────────────────────────────────────────────────────────

class _BoardCardList extends StatelessWidget {
  const _BoardCardList({required this.groups, required this.grouped});

  final List<BoardGroup> groups;

  /// When true, each non-empty group is preceded by a cohort section header.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final group in groups)
          if (group.boards.isNotEmpty) ...[
            if (grouped) _GroupHeader(group: group),
            for (final board in group.boards) ...[
              _BoardCard(board: board),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _BoardCard extends ConsumerWidget {
  const _BoardCard({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(board.name, style: AppTypography.headlineSm),
              ),
              StatusChip(label: board.type, tone: StatusTone.info),
            ],
          ),
          if (board.description != null &&
              board.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              board.description!,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _OptionBadges(board: board),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: '수정',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _BoardFormDialog(board: board),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: '삭제',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.tertiary,
                onPressed: () => _confirmDelete(context, ref, board),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionBadges extends StatelessWidget {
  const _OptionBadges({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (board.allowAnonymous)
        const StatusChip(
          label: '익명 허용',
          tone: StatusTone.neutral,
          icon: Icons.visibility_off_outlined,
        ),
      if (board.allowPrivatePost)
        const StatusChip(
          label: '비밀글 허용',
          tone: StatusTone.neutral,
          icon: Icons.lock_outline_rounded,
        ),
    ];
    if (chips.isEmpty) {
      return Text(
        '옵션 없음',
        style:
            AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }
}

String _visibilityLabel(String visibility) => switch (visibility) {
      'cohort' => '특정 기수',
      'institution' => '기수 전체',
      'public' => '전체 공개',
      _ => visibility,
    };

/// Extracts the leading integer "cohort number" from a cohort label so the
/// printer-page range (typed as bare numbers) can be matched to a cohort id.
/// e.g. `"1기"` → 1, `"3기 (백엔드)"` → 3. Returns null when no leading digits.
int? _cohortNumberFromName(String name) {
  final match = RegExp(r'\d+').firstMatch(name);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

/// Resolution of a typed cohort range against the (role-scoped) cohort options.
///
/// [targets] are the cohorts the user may create boards for. [notAssignable]
/// are cohort numbers that were typed but have no matching option the caller is
/// allowed to target — for an instructor this means a cohort they're NOT
/// assigned to (the backend scopes `cohortOptionsProvider` by role, so an
/// unassigned cohort simply isn't present). These are EXCLUDED from the batch
/// and surfaced as a warning.
class _CohortResolution {
  const _CohortResolution({
    required this.targets,
    required this.notAssignable,
    required this.invalidTokens,
  });

  final List<BoardCohortTarget> targets;
  final List<int> notAssignable;
  final List<String> invalidTokens;

  bool get hasWarnings => notAssignable.isNotEmpty || invalidTokens.isNotEmpty;
}

/// Maps a parsed [range] to creatable [BoardCohortTarget]s using the available
/// (role-scoped) [options]. Numbers without a matching assignable cohort are
/// reported in [_CohortResolution.notAssignable] and excluded.
_CohortResolution _resolveCohortTargets(
  CohortRange range,
  List<CohortOption> options,
) {
  // Build number → option, preferring the leading number in the name and
  // falling back to the raw id so unconventional names still resolve.
  final byNumber = <int, CohortOption>{};
  for (final option in options) {
    final n = _cohortNumberFromName(option.name) ?? option.id;
    byNumber.putIfAbsent(n, () => option);
  }

  final targets = <BoardCohortTarget>[];
  final notAssignable = <int>[];
  for (final n in range.numbers) {
    final option = byNumber[n];
    if (option == null) {
      notAssignable.add(n);
      continue;
    }
    targets.add(
      BoardCohortTarget(cohortId: option.id, cohortName: option.name),
    );
  }
  return _CohortResolution(
    targets: targets,
    notAssignable: notAssignable,
    invalidTokens: range.invalidTokens,
  );
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, Board board) async {
  final ok = await showConfirmDialog(
    context,
    title: '"${board.name}" 게시판을 삭제하시겠습니까?',
    message: '삭제하면 게시판과 연결된 글 접근이 중단됩니다. 이 작업은 되돌릴 수 없습니다.',
    confirmLabel: '삭제',
    destructive: true,
  );
  if (!ok) return;
  try {
    await ref.read(boardManagementProvider.notifier).remove(board.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('"${board.name}" 게시판을 삭제했습니다.')));
    }
  } on BoardException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// ── Create / edit dialog ────────────────────────────────────────────────────

/// A dialog that creates a board (when [board] is null) or edits an existing
/// one. The `type` field is immutable after creation (server has no type
/// update), so it's disabled in edit mode.
class _BoardFormDialog extends ConsumerStatefulWidget {
  const _BoardFormDialog({this.board});

  final Board? board;

  @override
  ConsumerState<_BoardFormDialog> createState() => _BoardFormDialogState();
}

class _BoardFormDialogState extends ConsumerState<_BoardFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _typeController;

  /// Printer-page-style cohort range (e.g. `"1,2,5-7"`). Only used when
  /// composing a new board with visibility = `cohort` (특정 기수). On submit it's
  /// parsed + mapped to cohort ids and fanned out into one board per cohort.
  late final TextEditingController _cohortRangeController;
  late String _visibility;
  late bool _allowAnonymous;
  late bool _allowPrivatePost;

  bool _submitting = false;
  String? _error;

  /// Common presets surfaced as quick chips; the field itself accepts any
  /// free-text value (#1 — custom types allowed).
  static const _typePresets = <String>['공지', '자유', '질문/답변', '자료실'];
  // "기수 전체"(institution-wide, within 동아AI랩) is the default and listed
  // first. The old "전체 공개"(public/cross-org) option was removed — the backend
  // has no cross-institution sharing and boards aren't tenant-isolated yet, so
  // it had no real behavior and risked confusion (see 멀티테넌시 memo).
  static const _visibilities = <(String, String)>[
    ('institution', '기수 전체'),
    ('cohort', '특정 기수'),
  ];

  bool get _isEditing => widget.board != null;

  @override
  void initState() {
    super.initState();
    final b = widget.board;
    _nameController = TextEditingController(text: b?.name ?? '');
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _typeController = TextEditingController(text: b?.type ?? '');
    _cohortRangeController = TextEditingController();
    _allowAnonymous = b?.allowAnonymous ?? false;
    _allowPrivatePost = b?.allowPrivatePost ?? false;
    // Default to institution-wide ("기수 전체") per #4.
    _visibility = b?.visibility.isNotEmpty == true ? b!.visibility : 'institution';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _typeController.dispose();
    _cohortRangeController.dispose();
    super.dispose();
  }

  bool get _isValid => _nameController.text.trim().isNotEmpty;

  /// True when composing a new "특정 기수"(cohort-scoped) board, which requires a
  /// cohort range and triggers batch-create (one board per selected cohort).
  bool get _isCohortCreate => !_isEditing && _visibility == 'cohort';

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    // Cohort-scoped creation goes through the batch path so a range expands to
    // one board per cohort.
    if (_isCohortCreate) {
      await _submitCohortBatch();
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final notifier = ref.read(boardManagementProvider.notifier);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    try {
      if (_isEditing) {
        await notifier.edit(
          widget.board!.id,
          name: name,
          description: description,
          allowAnonymous: _allowAnonymous,
          allowPrivatePost: _allowPrivatePost,
          visibility: _visibility,
        );
      } else {
        // visibility == 'institution' → a single institution-wide board, no
        // cohort id (#1: cohort_id null).
        await notifier.create(
          name: name,
          type: _typeController.text.trim().isEmpty
              ? '자유'
              : _typeController.text.trim(),
          description: description.isEmpty ? null : description,
          allowAnonymous: _allowAnonymous,
          allowPrivatePost: _allowPrivatePost,
          visibility: _visibility,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_isEditing ? '게시판을 수정했습니다.' : '게시판을 개설했습니다.')),
        );
    } on BoardException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Handles "특정 기수" creation: parse the range, map to assignable cohorts,
  /// warn about/exclude cohorts the creator can't target, optionally confirm,
  /// then batch-create one board per cohort.
  Future<void> _submitCohortBatch() async {
    final range = parseCohortRange(_cohortRangeController.text);
    if (range.isEmpty) {
      setState(() => _error = '대상 기수를 입력하세요. 예: 1,2,5-7');
      return;
    }

    // cohortOptionsProvider is role-scoped server-side: operations see every
    // institution cohort, an instructor sees only their assigned cohorts. So a
    // missing option == "not assignable for this user".
    final options = ref.read(cohortOptionsProvider).value ?? const [];
    if (options.isEmpty) {
      setState(() => _error = '기수 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    final resolution = _resolveCohortTargets(range, options);
    if (resolution.targets.isEmpty) {
      setState(() {
        _error = resolution.notAssignable.isNotEmpty
            ? '개설 권한이 있는 기수가 없습니다. 담당 기수만 게시판을 개설할 수 있습니다.'
            : '유효한 대상 기수를 찾지 못했습니다. 입력을 확인해주세요.';
      });
      return;
    }

    // If some typed cohorts were excluded (typo, or — for instructors — not an
    // assigned cohort), surface a clear warning and let the creator decide to
    // proceed with the assignable subset only.
    if (resolution.hasWarnings) {
      final proceed = await _confirmExclusions(resolution);
      if (proceed != true) return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final baseName = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final type = _typeController.text.trim().isEmpty
        ? '자유'
        : _typeController.text.trim();
    try {
      final result =
          await ref.read(boardManagementProvider.notifier).createBatch(
                targets: resolution.targets,
                baseName: baseName,
                type: type,
                description: description.isEmpty ? null : description,
                allowAnonymous: _allowAnonymous,
                allowPrivatePost: _allowPrivatePost,
              );
      if (!mounted) return;

      if (result.createdCount == 0) {
        setState(() {
          _submitting = false;
          _error = result.failures.isNotEmpty
              ? result.failures.first.message
              : '게시판을 개설하지 못했습니다.';
        });
        return;
      }

      Navigator.of(context).pop();
      final message = result.allSucceeded
          ? '${result.createdCount}개 기수에 게시판을 개설했습니다.'
          : '${result.createdCount}개 개설 완료, ${result.failureCount}개 실패했습니다.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } on BoardException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Confirms proceeding when some typed cohorts are excluded — either invalid
  /// tokens (typos) or cohorts the creator isn't allowed to target (instructor
  /// not assigned). Lists exactly what will be created vs. skipped.
  Future<bool?> _confirmExclusions(_CohortResolution resolution) {
    final willCreate =
        resolution.targets.map((t) => t.cohortName).join(', ');
    final notAssignable = resolution.notAssignable.map((n) => '$n기').join(', ');
    final invalid = resolution.invalidTokens.join(', ');

    final buffer = StringBuffer();
    if (notAssignable.isNotEmpty) {
      buffer.writeln('개설 권한이 없어 제외됩니다(담당 기수 아님): $notAssignable');
    }
    if (invalid.isNotEmpty) {
      buffer.writeln('인식하지 못한 입력(제외): $invalid');
    }
    buffer.write('개설 대상: $willCreate');

    return showConfirmDialog(
      context,
      title: '일부 기수가 제외됩니다',
      message: buffer.toString(),
      confirmLabel: '계속 개설',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? '게시판 수정' : '게시판 개설',
                style: AppTypography.headlineSm,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '게시판 이름을 입력하세요',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _typeController,
                enabled: !_isEditing, // type is immutable after creation
                decoration: const InputDecoration(
                  labelText: '유형',
                  hintText: '예: 공지, 자유, 질문/답변 — 직접 입력 가능',
                ),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final preset in _typePresets)
                      ActionChip(
                        label: Text(preset),
                        onPressed: () =>
                            setState(() => _typeController.text = preset),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '설명 (선택)',
                  hintText: '게시판 용도를 간단히 설명하세요',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: '공개범위'),
                onChanged: (v) => setState(() => _visibility = v ?? _visibility),
                items: [
                  for (final v in _visibilities)
                    DropdownMenuItem(value: v.$1, child: Text(v.$2)),
                ],
              ),
              // "특정 기수" → require a cohort range; each selected cohort gets its
              // own board (backend is one-cohort-per-board, so we batch-create).
              if (_isCohortCreate) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _cohortRangeController,
                  keyboardType: TextInputType.text,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '대상 기수',
                    hintText: '예: 1,2,5-7',
                    helperText: '쉼표로 여러 기수, 하이픈으로 범위를 입력합니다 '
                        '(예: 1,2,5-7). 선택한 기수마다 게시판이 각각 하나씩 개설됩니다.',
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _CohortRangePreview(rawRange: _cohortRangeController.text),
              ],
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
                value: _allowAnonymous,
                onChanged: (v) => setState(() => _allowAnonymous = v),
                title: Text('익명 작성 허용', style: AppTypography.bodyMd),
                subtitle: Text(
                  '작성자가 글을 "익명"으로 올릴 수 있습니다.',
                  style: AppTypography.labelSm,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
                value: _allowPrivatePost,
                onChanged: (v) => setState(() => _allowPrivatePost = v),
                title: Text('비밀글 작성 허용', style: AppTypography.bodyMd),
                subtitle: Text(
                  '작성자와 운영팀만 열람할 수 있는 글을 허용합니다.',
                  style: AppTypography.labelSm,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: '취소',
                    variant: AppButtonVariant.tertiary,
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: _isEditing
                        ? '저장'
                        : (_isCohortCreate ? '기수별 개설' : '개설'),
                    icon: Icons.check_rounded,
                    loading: _submitting,
                    // In cohort mode also require a non-empty range so the user
                    // can't submit an empty target.
                    onPressed: _isValid &&
                            (!_isCohortCreate ||
                                _cohortRangeController.text.trim().isNotEmpty)
                        ? _submit
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live preview under the cohort-range field: resolves the typed range against
/// the (role-scoped) cohort options and shows which cohorts will each receive a
/// board, plus any excluded (not-assignable / unrecognized) tokens. Purely
/// advisory — the authoritative resolution runs again on submit.
class _CohortRangePreview extends ConsumerWidget {
  const _CohortRangePreview({required this.rawRange});

  final String rawRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rawRange.trim().isEmpty) return const SizedBox.shrink();

    final range = parseCohortRange(rawRange);
    final optionsAsync = ref.watch(cohortOptionsProvider);

    return optionsAsync.when(
      loading: () => Text(
        '기수 정보를 불러오는 중입니다…',
        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
      ),
      error: (_, _) => Text(
        '기수 정보를 불러오지 못했습니다.',
        style: AppTypography.labelSm.copyWith(color: AppColors.error),
      ),
      data: (options) {
        final resolution = _resolveCohortTargets(range, options);
        final excluded = <String>[
          ...resolution.notAssignable.map((n) => '$n기'),
          ...resolution.invalidTokens,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resolution.targets.isEmpty)
              Text(
                '개설 가능한 대상 기수가 없습니다.',
                style: AppTypography.labelSm.copyWith(color: AppColors.error),
              )
            else
              Text(
                '개설 대상 ${resolution.targets.length}개: '
                '${resolution.targets.map((t) => t.cohortName).join(', ')}',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            if (excluded.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '제외: ${excluded.join(', ')} '
                      '(담당하지 않는 기수이거나 인식할 수 없는 입력)',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
