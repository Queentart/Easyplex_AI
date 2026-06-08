import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/admin_attendance_model.dart';
import '../admin_attendance_provider.dart';

/// 운영팀(admin_ops) 출결 CSV 가져오기 화면.
///
/// Rendered inside the authenticated app shell (no Scaffold/AppBar here).
///
/// 흐름(서버가 진실의 원천):
///   1. 대상 기수 ID 입력 + CSV 선택(파일 선택 seam) 또는 CSV 텍스트 붙여넣기
///   2. "미리보기" → `dry_run=true` 호출로 변경 예정 내용 확인(쓰기 없음)
///   3. 확인 다이얼로그 → "가져오기 실행" → `dry_run=false`로 실제 반영
///   4. 가져오기 이력 표시 + 과거 배치 롤백(되돌리기) 제공
///
/// file_picker 패키지가 없으므로 파일 선택은 [adminCsvPickerProvider] seam 뒤로
/// 추상화되어 있으며, 미구현 시 "준비 중" 안내 후 텍스트 붙여넣기로 대체합니다.
class CsvUploadScreen extends ConsumerWidget {
  const CsvUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('출결 CSV 가져오기', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '출결 데이터를 CSV로 일괄 등록합니다. 실행 전 미리보기로 변경 내용을 확인하세요.',
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ImportWizard(),
          const SizedBox(height: AppSpacing.xl),
          Text('가져오기 이력', style: AppTypography.headlineSm),
          const SizedBox(height: AppSpacing.md),
          const _ImportHistory(),
        ],
      ),
    );
  }
}

/// The pick → preview → confirm → commit wizard, driven by [csvImportProvider].
class _ImportWizard extends ConsumerStatefulWidget {
  const _ImportWizard();

  @override
  ConsumerState<_ImportWizard> createState() => _ImportWizardState();
}

class _ImportWizardState extends ConsumerState<_ImportWizard> {
  final _cohortController = TextEditingController();
  final _csvController = TextEditingController();

  @override
  void dispose() {
    _cohortController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(csvImportProvider);
    final notifier = ref.read(csvImportProvider.notifier);

    // Committed → success card with a "다시 가져오기" reset.
    if (state.phase == CsvImportPhase.committed && state.committed != null) {
      return _CommittedCard(
        result: state.committed!,
        onReset: () {
          _csvController.clear();
          notifier.reset();
        },
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 대상 기수 ─────────────────────────────────────────────
          Text('대상 기수 ID',
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _cohortController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '예) 1'),
            onChanged: (v) => notifier.setCohortId(int.tryParse(v.trim())),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 파일 선택 / 붙여넣기 ───────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('CSV 데이터',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ),
              AppButton(
                label: 'CSV 파일 선택',
                icon: Icons.attach_file_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => _onPickFile(notifier),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _csvController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'date,user_id,type\n2026-05-01,12,present\n2026-05-01,13,late',
            ),
            onChanged: (v) {
              if (v.trim().isEmpty) return;
              notifier.setUpload(CsvUpload.fromText(v));
            },
          ),
          if (state.upload != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 16, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    state.upload!.fileName,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],

          // ── 오류 ──────────────────────────────────────────────────
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: state.error!),
          ],

          const SizedBox(height: AppSpacing.lg),

          // ── 미리보기 액션 ─────────────────────────────────────────
          AppButton(
            label: '미리보기 (dry-run)',
            icon: Icons.visibility_outlined,
            expand: true,
            loading: state.phase == CsvImportPhase.previewing,
            onPressed: state.canPreview ? notifier.preview : null,
          ),

          // ── 미리보기 결과 + 확인 ──────────────────────────────────
          if (state.phase == CsvImportPhase.preview && state.preview != null) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            _PreviewSection(result: state.preview!),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '가져오기 실행',
              icon: Icons.cloud_upload_outlined,
              expand: true,
              loading: state.phase == CsvImportPhase.committing,
              onPressed: state.preview!.isEmpty
                  ? null
                  : () => _onConfirm(context, notifier, state.preview!),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onPickFile(CsvImportNotifier notifier) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ref.read(adminCsvPickerProvider);
      final upload = await picker();
      if (upload != null) {
        _csvController.clear();
        notifier.setUpload(upload);
      }
    } on CsvPickerUnavailable catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _onConfirm(
    BuildContext context,
    CsvImportNotifier notifier,
    ImportResult preview,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: '출결 데이터를 가져오시겠습니까?',
      message: '신규 ${preview.imported}건 · 수정 ${preview.updated}건 · '
          '건너뜀 ${preview.skipped}건이 반영됩니다.\n'
          '가져온 후에는 이력에서 롤백할 수 있습니다.',
      confirmLabel: '가져오기 실행',
    );
    if (!confirmed) return;

    await notifier.confirm();
    final after = ref.read(csvImportProvider);
    if (after.phase == CsvImportPhase.committed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('출결 데이터를 가져왔습니다.')),
      );
    }
  }
}

/// Preview (dry-run) result: would-be counts + a sample of preview rows.
class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('미리보기 결과', style: AppTypography.headlineSm),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusChip(label: '신규 ${result.imported}', tone: StatusTone.success),
            StatusChip(label: '수정 ${result.updated}', tone: StatusTone.info),
            StatusChip(
              label: '건너뜀 ${result.skipped}',
              tone: result.skipped > 0 ? StatusTone.warning : StatusTone.neutral,
            ),
          ],
        ),
        if (result.isEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '반영될 변경 사항이 없습니다. CSV 내용을 확인하세요.',
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ] else if (result.preview.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _PreviewTable(rows: result.preview),
        ],
      ],
    );
  }
}

/// Renders the free-form preview rows using the columns the server emitted.
class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.rows});

  final List<ImportPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    // Derive columns from the first row (server-defined order); cap visible rows.
    final columns = rows.first.columns;
    if (columns.isEmpty) return const SizedBox.shrink();
    final visible = rows.take(20).toList();

    return AppDataTable(
      columns: columns,
      rows: [
        for (final row in visible)
          AppTableRow(
            cells: [
              for (final col in columns) Text(row.fields[col] ?? '-'),
            ],
          ),
      ],
    );
  }
}

/// Success card after a committed import.
class _CommittedCard extends StatelessWidget {
  const _CommittedCard({required this.result, required this.onReset});

  final ImportResult result;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('가져오기 완료', style: AppTypography.headlineSm),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(label: '신규 ${result.imported}', tone: StatusTone.success),
              StatusChip(label: '수정 ${result.updated}', tone: StatusTone.info),
              StatusChip(label: '건너뜀 ${result.skipped}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '배치 ID: ${result.batchId}',
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '다시 가져오기',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

/// Import-history list with per-batch rollback.
class _ImportHistory extends ConsumerWidget {
  const _ImportHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(importHistoryProvider);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: LoadingView(message: '가져오기 이력을 불러오는 중입니다…'),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(importHistoryProvider.notifier).refresh(),
        ),
      ),
      data: (logs) => logs.isEmpty
          ? const AppCard(
              child: EmptyState(
                title: '가져오기 이력이 없습니다',
                description: '위에서 CSV를 가져오면 이력이 여기에 표시됩니다.',
                icon: Icons.history_outlined,
              ),
            )
          : _HistoryTable(logs: logs),
    );
  }
}

class _HistoryTable extends ConsumerWidget {
  const _HistoryTable({required this.logs});

  final List<ImportLog> logs;

  StatusTone _toneFor(ImportStatus status) {
    switch (status) {
      case ImportStatus.completed:
        return StatusTone.success;
      case ImportStatus.pending:
        return StatusTone.info;
      case ImportStatus.failed:
        return StatusTone.danger;
      case ImportStatus.rolledBack:
        return StatusTone.warning;
      case ImportStatus.unknown:
        return StatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const ['일시', '파일', '행', '상태', '관리'],
      columnFlex: const [3, 4, 2, 2, 2],
      rows: [
        for (final log in logs)
          AppTableRow(
            cells: [
              Text(DateFormatter.dateTime(log.createdAt)),
              Text(
                log.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('${log.successCount}/${log.rowCount}'),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: log.status.label,
                  tone: _toneFor(log.status),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: log.status.canRollback
                    ? AppButton(
                        label: '롤백',
                        icon: Icons.undo_outlined,
                        variant: AppButtonVariant.tertiary,
                        onPressed: () => _onRollback(context, ref, log),
                      )
                    : const Text('-'),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _onRollback(
    BuildContext context,
    WidgetRef ref,
    ImportLog log,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '이 가져오기를 롤백하시겠습니까?',
      message: '${DateFormatter.dateTime(log.createdAt)}에 가져온 '
          '"${log.fileName}" 배치로 생성된 출결 기록이 모두 삭제됩니다.\n'
          '이 작업은 되돌릴 수 없습니다.',
      confirmLabel: '롤백',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(importHistoryProvider.notifier).rollback(log.batchId);
      messenger.showSnackBar(
        const SnackBar(content: Text('가져오기를 롤백했습니다.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Inline error block (no retry — used for transient form errors).
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
