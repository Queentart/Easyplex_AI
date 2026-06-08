import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../instructor/presentation/instructor_dashboard_provider.dart';
import '../../data/attendance_repository.dart';
import '../../data/instructor_attendance_repository.dart';
import '../../domain/attendance_model.dart';
import '../attendance_management_provider.dart';
import 'attendance_roster_view.dart';

/// 강사용 기수(코호트) 출결 관리 화면 — 표준 로스터(수강생별) 뷰.
///
/// Rendered inside the authenticated app shell (top bar + side nav are supplied
/// by the shell), so this widget returns page content only — no Scaffold/AppBar.
///
/// 구성:
///   - 상단 컨트롤: 기간(월) + 정렬
///   - 전체 출석률 / 인원수 / 지각·결석 합계 요약
///   - 수강생별 로스터 테이블(1인 1행, 위험 행 강조)
///   - 행 탭 → 해당 수강생의 일자별 기록 시트, 각 기록에 정정(사유 필수)·알림 액션
///
/// 강사는 본인 담당 기수에 한정됩니다: [instructorCohortIdProvider]로 해석하며,
/// 글로벌 선택 기수가 본인 담당이면 그 기수를, 아니면 담당 기수 목록의 첫 기수를
/// 사용합니다(강사의 담당 기수는 instructor_cohorts 조인으로 결정). 정정/알림은
/// 운영팀·강사만 가능하며(백엔드 require_roles), "3 지각 = 1 결석" 등의 환산은
/// 선택 기간의 기록으로부터 집계됩니다(domain/attendance_roster.dart).
class InstructorAttendanceScreen extends ConsumerWidget {
  const InstructorAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Instructor scope: the global cohort selection when it belongs to this
    // instructor, else their first taught cohort (resolved from cohortIds).
    // The backend still scopes records to cohorts the instructor may see.
    final cohortId = ref.watch(instructorCohortIdProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('기수 출결 관리', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '담당 기수의 수강생별 출결 현황을 확인하고 정정·알림을 처리합니다.',
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (cohortId == null)
            const AppCard(
              child: EmptyState(
                title: '담당 기수가 없습니다',
                description: '배정된 기수가 있어야 출결을 관리할 수 있습니다.',
                icon: Icons.groups_outlined,
              ),
            )
          else
            _CohortRoster(cohortId: cohortId),
        ],
      ),
    );
  }
}

/// Roster body for a resolved cohort: loads the month-scoped roster and renders
/// the shared [AttendanceRosterView] with per-record 정정/알림 actions.
class _CohortRoster extends ConsumerWidget {
  const _CohortRoster({required this.cohortId});

  final int cohortId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(managementMonthProvider);
    final scope = RosterScope(cohortId: cohortId, month: month);
    final rosterAsync = ref.watch(instructorRosterProvider(scope));

    return rosterAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: LoadingView(message: '출결 현황을 불러오는 중입니다…'),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: ErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.read(instructorRosterProvider(scope).notifier).refresh(),
        ),
      ),
      data: (roster) => AttendanceRosterView(
        roster: roster,
        month: month,
        onSelectMonth: (m) =>
            ref.read(managementMonthProvider.notifier).select(m),
        recordActionBuilder: (sheetContext, record) => _RecordActions(
          cohortId: cohortId,
          scope: scope,
          record: record,
        ),
      ),
    );
  }
}

/// Per-record actions inside the drill-down sheet: 정정(manual correction) +
/// 알림(notify). Both confirm before acting; correction requires a reason.
class _RecordActions extends ConsumerWidget {
  const _RecordActions({
    required this.cohortId,
    required this.scope,
    required this.record,
  });

  final int cohortId;
  final RosterScope scope;
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        AppButton(
          label: '정정',
          icon: Icons.edit_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => _onCorrect(context, ref),
        ),
        AppButton(
          label: '알림',
          icon: Icons.notifications_active_outlined,
          variant: AppButtonVariant.tertiary,
          onPressed: () => _onNotify(context, ref),
        ),
      ],
    );
  }

  Future<void> _onCorrect(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CorrectionResult>(
      context: context,
      builder: (_) => _CorrectionDialog(record: record),
    );
    if (result == null) return;

    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '출결을 정정하시겠습니까?',
      message: '${DateFormatter.date(record.date)} · 수강생 #${record.userId}\n'
          '${record.type.label} → ${result.type.label}\n사유: ${result.reason}',
      confirmLabel: '정정',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(instructorAttendanceRepositoryProvider).correctRecord(
            recordId: record.id,
            type: result.type,
            reason: result.reason,
          );
      // Refresh the roster so the table + (reopened) sheet reflect the change.
      await ref.read(instructorRosterProvider(scope).notifier).refresh();
      // Close the now-stale detail sheet so the manager sees the fresh roster.
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('출결을 정정했습니다.')),
      );
    } on AttendanceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _onNotify(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '결석 알림을 보내시겠습니까?',
      message: '수강생 #${record.userId}에게 '
          '${DateFormatter.date(record.date)} 출결 관련 알림을 발송합니다.',
      confirmLabel: '발송',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(instructorAttendanceRepositoryProvider).notify(
            cohortId: cohortId,
            userIds: [record.userId],
            message: '${DateFormatter.date(record.date)} 출결(${record.type.label}) '
                '확인이 필요합니다.',
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('알림을 발송했습니다.')),
      );
    } on AttendanceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Result returned from [_CorrectionDialog]: the chosen type + the reason.
class _CorrectionResult {
  const _CorrectionResult({required this.type, required this.reason});

  final AttendanceType type;
  final String reason;
}

/// Manual-correction dialog: pick a new status + enter a mandatory reason.
///
/// The reason is required because the backend enforces `note` `min_length=1`;
/// the confirm button stays disabled until a reason is entered.
class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.record});

  final AttendanceRecord record;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  static const _selectableTypes = <AttendanceType>[
    AttendanceType.present,
    AttendanceType.late,
    AttendanceType.absent,
    AttendanceType.earlyLeave,
    AttendanceType.medical,
    AttendanceType.official,
  ];

  late AttendanceType _type;
  final _reasonController = TextEditingController();
  bool _hasReason = false;

  @override
  void initState() {
    super.initState();
    _type = _selectableTypes.contains(widget.record.type)
        ? widget.record.type
        : AttendanceType.present;
    _reasonController.addListener(() {
      final has = _reasonController.text.trim().isNotEmpty;
      if (has != _hasReason) setState(() => _hasReason = has);
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Text('출결 수동 정정', style: AppTypography.headlineSm),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${DateFormatter.date(widget.record.date)} · '
              '수강생 #${widget.record.userId}',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('변경할 상태',
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<AttendanceType>(
              initialValue: _type,
              items: [
                for (final t in _selectableTypes)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('정정 사유 (필수)',
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예) 본인 소명 및 증빙 확인 후 출석 처리',
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
                  onPressed: _hasReason
                      ? () => Navigator.of(context).pop(
                            _CorrectionResult(
                              type: _type,
                              reason: _reasonController.text.trim(),
                            ),
                          )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
