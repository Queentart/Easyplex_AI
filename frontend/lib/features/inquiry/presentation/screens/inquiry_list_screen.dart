import '../../../../core/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_header.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/cohort_filter_spec.dart';
import '../../domain/inquiry_model.dart';
import '../inquiry_provider.dart';

/// Maps an inquiry status to a chip tone.
StatusTone statusTone(InquiryStatus s) => switch (s) {
      InquiryStatus.open => StatusTone.info,
      InquiryStatus.inProgress => StatusTone.warning,
      InquiryStatus.resolved => StatusTone.success,
      InquiryStatus.closed => StatusTone.neutral,
    };

/// Maps an inquiry priority to a chip tone.
StatusTone priorityTone(InquiryPriority p) => switch (p) {
      InquiryPriority.low => StatusTone.neutral,
      InquiryPriority.normal => StatusTone.info,
      InquiryPriority.high => StatusTone.warning,
      InquiryPriority.urgent => StatusTone.danger,
    };

/// Shared inquiry/ticket list screen, mounted under both `/ops/issues` and
/// `/tech/issues`. [basePath] decides where row taps and the create FAB
/// navigate (so the same screen serves both areas).
///
/// Operations/Tech see a data table on wide layouts and a card list on mobile.
class InquiryListScreen extends ConsumerStatefulWidget {
  const InquiryListScreen({super.key, required this.basePath});

  /// Either `/ops/issues` or `/tech/issues`.
  final String basePath;

  @override
  ConsumerState<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends ConsumerState<InquiryListScreen> {
  InquiryStatus? _statusFilter;

  InquiryListArgs get _args => InquiryListArgs(status: _statusFilter?.code);

  @override
  Widget build(BuildContext context) {
    final inquiries = ref.watch(inquiryListProvider(_args));
    final listMeta = ref.watch(inquiryListMetaProvider(_args));
    final cohortSpec = ref.watch(inquiryCohortFilterProvider(widget.basePath));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListHeader(
              title: AppLabels.inquiries,
              action: AppButton(
                label: '새 문의',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () => context.push('${widget.basePath}/new'),
              ),
            ),
            _StatusFilterBar(
              selected: _statusFilter,
              onChanged: (s) => setState(() => _statusFilter = s),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CohortFilterBar(basePath: widget.basePath, spec: cohortSpec),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: inquiries.when(
                loading: () => const LoadingView(message: '문의 목록을 불러오는 중입니다'),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(inquiryListProvider(_args).notifier).refresh(),
                ),
                data: (all) {
                  // 2nd-level cohort filter applied CLIENT-SIDE (backend exposes
                  // no cohort_id query param; each inquiry carries cohort_id).
                  final items = cohortSpec.isEmpty
                      ? all
                      : all
                          .where((i) => cohortSpec.matches(i.cohortId))
                          .toList();
                  // More rows may live on the server beyond what is loaded; the
                  // client-side cohort filter narrows the loaded set further, so
                  // a "더 보기" affordance is shown whenever the backend has more.
                  final hasMore = listMeta.hasMore;
                  final isLoadingMore = listMeta.isLoadingMore;
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => ref
                          .read(inquiryListProvider(_args).notifier)
                          .refresh(),
                      child: ListView(
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          EmptyState(
                            icon: Icons.support_agent_outlined,
                            title: '문의가 없습니다',
                            description: _emptyDescription(cohortSpec),
                          ),
                          if (hasMore)
                            _LoadMoreFooter(
                              isLoading: isLoadingMore,
                              onPressed: () => ref
                                  .read(inquiryListProvider(_args).notifier)
                                  .loadMore(),
                            ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => ref
                        .read(inquiryListProvider(_args).notifier)
                        .refresh(),
                    child: ResponsiveLayout(
                      mobile: (_) => _InquiryCardList(
                        items: items,
                        basePath: widget.basePath,
                        hasMore: hasMore,
                        isLoadingMore: isLoadingMore,
                        onLoadMore: () => ref
                            .read(inquiryListProvider(_args).notifier)
                            .loadMore(),
                      ),
                      tablet: (_) => _InquiryTable(
                        items: items,
                        basePath: widget.basePath,
                        hasMore: hasMore,
                        isLoadingMore: isLoadingMore,
                        onLoadMore: () => ref
                            .read(inquiryListProvider(_args).notifier)
                            .loadMore(),
                      ),
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

  String _emptyDescription(CohortFilterSpec spec) {
    if (!spec.isEmpty) return '\'${spec.summary}\' 조건에 해당하는 문의가 없습니다.';
    if (_statusFilter == null) return '새 문의를 등록하면 이곳에 표시됩니다.';
    return '해당 상태의 문의가 없습니다.';
  }
}

/// In-screen (2nd-level) cohort filter bar for operators. Tapping it opens a
/// dialog where the operator types a cohort expression (single / multiple /
/// range / "이후"). Pre-filled from the global nav cohort selection.
class _CohortFilterBar extends ConsumerWidget {
  const _CohortFilterBar({required this.basePath, required this.spec});

  final String basePath;
  final CohortFilterSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 18, color: AppColors.outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Material(
              color: spec.isEmpty
                  ? AppColors.surfaceContainerLow
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => _openDialog(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '기수 필터: ${spec.summary}',
                          style: AppTypography.labelMd.copyWith(
                            color: spec.isEmpty
                                ? AppColors.onSurfaceVariant
                                : AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.tune_rounded,
                          size: 16, color: AppColors.outline),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!spec.isEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: '기수 필터 해제',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => ref
                  .read(inquiryCohortFilterProvider(basePath).notifier)
                  .clear(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _CohortFilterDialog(initial: spec.raw),
    );
    if (result == null) return;
    ref.read(inquiryCohortFilterProvider(basePath).notifier).apply(result);
  }
}

class _CohortFilterDialog extends StatefulWidget {
  const _CohortFilterDialog({required this.initial});

  final String initial;

  @override
  State<_CohortFilterDialog> createState() => _CohortFilterDialogState();
}

class _CohortFilterDialogState extends State<_CohortFilterDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = CohortFilterSpec.parse(_ctrl.text);
    return AlertDialog(
      title: const Text('기수별 문의 보기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '특정 기수, 여러 기수, 범위, 또는 특정 기수 이후를 입력하세요.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '예) 3  ·  1,2,5  ·  5-7  ·  5+ (5기 이후)',
            style: AppTypography.bodySm.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '예: 1,2,5-7'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview.isEmpty ? '적용 대상: 전체 기수' : '적용 대상: ${preview.summary}',
            style: AppTypography.labelSm.copyWith(color: AppColors.primary),
          ),
          if (preview.hasErrors) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '인식할 수 없는 입력: ${preview.invalidTokens.join(', ')}',
              style: AppTypography.labelSm.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: const Text('전체 기수'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onChanged});

  final InquiryStatus? selected;
  final ValueChanged<InquiryStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _FilterChip(
            label: '전체',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final s in InquiryStatus.values) ...[
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: s.label,
              selected: selected == s,
              onTap: () => onChanged(s),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _InquiryCardList extends StatefulWidget {
  const _InquiryCardList({
    required this.items,
    required this.basePath,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<Inquiry> items;
  final String basePath;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  State<_InquiryCardList> createState() => _InquiryCardListState();
}

class _InquiryCardListState extends State<_InquiryCardList> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Triggers a load when the user scrolls near the bottom.
  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return ListView.separated(
      controller: _controller,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return _LoadMoreFooter(
            isLoading: widget.isLoadingMore,
            onPressed: widget.onLoadMore,
          );
        }
        final inq = items[i];
        return AppCard(
          onTap: () => context.push('${widget.basePath}/${inq.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inq.title,
                      style: AppTypography.headlineSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(
                    label: inq.statusEnum.label,
                    tone: statusTone(inq.statusEnum),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  StatusChip(label: inq.typeEnum.label),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(
                    label: inq.priorityEnum.label,
                    tone: priorityTone(inq.priorityEnum),
                  ),
                  const Spacer(),
                  Text(
                    DateFormatter.relative(inq.createdAt),
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InquiryTable extends StatefulWidget {
  const _InquiryTable({
    required this.items,
    required this.basePath,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<Inquiry> items;
  final String basePath;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  State<_InquiryTable> createState() => _InquiryTableState();
}

class _InquiryTableState extends State<_InquiryTable> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Triggers a load when the user scrolls near the bottom of the table.
  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDataTable(
            columnFlex: const [4, 2, 2, 2, 2],
            columns: const ['제목', '유형', '우선순위', '상태', '등록일'],
            rows: [
              for (final inq in widget.items)
                AppTableRow(
                  highlight: inq.priorityEnum == InquiryPriority.urgent,
                  cells: [
                    _LinkCell(
                      text: inq.title,
                      onTap: () =>
                          context.push('${widget.basePath}/${inq.id}'),
                    ),
                    Text(inq.typeEnum.label),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: inq.priorityEnum.label,
                        tone: priorityTone(inq.priorityEnum),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: inq.statusEnum.label,
                        tone: statusTone(inq.statusEnum),
                      ),
                    ),
                    Text(DateFormatter.date(inq.createdAt)),
                  ],
                ),
            ],
          ),
          if (widget.hasMore)
            _LoadMoreFooter(
              isLoading: widget.isLoadingMore,
              onPressed: widget.onLoadMore,
            ),
        ],
      ),
    );
  }
}

/// Footer shown at the end of a list/table when more rows remain on the server.
/// Shows a spinner while a page is loading, otherwise a "더 보기" button.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: const Text('더 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
      ),
    );
  }
}

class _LinkCell extends StatelessWidget {
  const _LinkCell({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySm.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
