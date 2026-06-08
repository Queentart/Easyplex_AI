import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../leave/domain/leave_model.dart';
import '../../../leave/presentation/leave_provider.dart';
import '../../domain/attendance_model.dart';
import '../attendance_provider.dart';

/// 수강생 본인의 출결 현황 화면.
///
/// Rendered inside the authenticated app shell (which supplies the top bar and
/// side navigation), so this widget returns scrollable page content only — no
/// Scaffold / AppBar of its own.
///
/// Layout:
///   - 월 선택 네비게이션 (이전/다음 + 드롭다운) — 기본값 = 이번 달
///   - 선택한 달 기준 출석률 원형 링([AppProgressRing]) + 유형별 카운트 요약
///   - 요약 바로 아래 "YYYY년 M월 기준" 표기로 기준 달을 명확히 표시
///   - 선택한 달의 특이사항(지각/결석/조퇴/병결/공결)만 표시하는 날짜별 리스트
///     (각 비출석일에는 사유/유형명을 라벨로 표시; "---" 플레이스홀더 없음)
///   - 각 특이사항 행에 "문서 제출" 버튼 → 조퇴·병결 신청 폼으로 날짜/유형 prefill
///
/// 요약(링 % + 카운트)은 서버 누적 요약이 아니라 SELECTED MONTH의 기록으로부터
/// 클라이언트에서 재계산합니다([studentMonthStatsProvider]).
class StudentAttendanceScreen extends ConsumerWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(attendanceSelectedMonthProvider);
    final statsAsync = ref.watch(studentMonthStatsProvider(month));
    final recordsAsync = ref.watch(studentAttendanceRecordsProvider(month));

    Future<void> onRefresh() {
      return ref.read(studentMonthRecordsProvider(month).notifier).refresh();
    }

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── 헤더 + 월 선택 ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text('출결 현황', style: AppTypography.headlineMd),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const _LeaveBalanceIndicator(),
                    ],
                  ),
                ),
                _MonthNavigator(
                  month: month,
                  onSelect: (m) => ref
                      .read(attendanceSelectedMonthProvider.notifier)
                      .select(m),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 요약(출석률 링 + 카운트) — 선택한 달 기준 ──────────────────
            statsAsync.when(
              loading: () => const _SectionLoading(
                message: '출결 요약을 불러오는 중입니다…',
              ),
              error: (error, _) => _SectionError(
                message: error.toString(),
                onRetry: () => ref
                    .read(studentMonthRecordsProvider(month).notifier)
                    .refresh(),
              ),
              data: (stats) => stats.isEmpty
                  ? _SummaryEmpty(month: month)
                  : _SummaryCard(stats: stats, month: month),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── 특이사항 헤더 ─────────────────────────────────────────
            Text('특이사항', style: AppTypography.headlineSm),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${month.label} · 출석을 제외한 기록만 표시됩니다',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),

            recordsAsync.when(
              loading: () => const _SectionLoading(
                message: '특이사항을 불러오는 중입니다…',
              ),
              error: (error, _) => _SectionError(
                message: error.toString(),
                onRetry: () => ref
                    .read(studentMonthRecordsProvider(month).notifier)
                    .refresh(),
              ),
              data: (records) => records.isEmpty
                  ? const _RecordsEmpty()
                  : _RecordList(records: records),
            ),
          ],
        ),
      ),
    );
  }
}

/// Month navigation: prev / next chevrons around a tappable month dropdown.
///
/// "Next" is disabled once the selected month reaches the current month (there
/// are no future records). The dropdown lists the last 12 months (current →
/// 11 months back) so a student can jump to any recent month directly.
class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({required this.month, required this.onSelect});

  final AttendanceMonth month;
  final ValueChanged<AttendanceMonth> onSelect;

  List<AttendanceMonth> _recentMonths() {
    var m = AttendanceMonth.current();
    final months = <AttendanceMonth>[];
    for (var i = 0; i < 12; i++) {
      months.add(m);
      m = m.previous;
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final canGoNext = !month.next.isAfterCurrent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: '이전 달',
          onPressed: () => onSelect(month.previous),
          visualDensity: VisualDensity.compact,
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<AttendanceMonth>(
            value: month,
            borderRadius: BorderRadius.circular(AppRadius.md),
            items: [
              for (final m in _recentMonths())
                DropdownMenuItem(
                  value: m,
                  child: Text(m.label, style: AppTypography.labelMd),
                ),
            ],
            onChanged: (m) {
              if (m != null) onSelect(m);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: '다음 달',
          onPressed: canGoNext ? () => onSelect(month.next) : null,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// Subtle "잔여 휴가 N일" indicator shown next to the screen title.
///
/// Watches [leaveBalanceProvider]. Renders nothing while loading or on error
/// (it is a secondary affordance and must never disrupt the page), shows
/// "잔여 N일" when the cohort has an allowance, and a muted "휴가 미설정" otherwise.
class _LeaveBalanceIndicator extends ConsumerWidget {
  const _LeaveBalanceIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveBalanceProvider);
    return async.maybeWhen(
      data: (balance) {
        if (!balance.hasAllowance) {
          return _Pill(
            icon: Icons.beach_access_outlined,
            label: '휴가 미설정',
            tone: AppColors.onSurfaceVariant,
          );
        }
        final remaining = balance.remainingDays ?? 0;
        return _Pill(
          icon: Icons.beach_access_outlined,
          label: '잔여 휴가 $remaining일',
          tone: remaining <= 0 ? AppColors.error : AppColors.primary,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// A small rounded label used for the leave-balance indicator.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.tone});

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

/// Summary card: month-scoped attendance-rate ring + counts + per-type chips.
///
/// All values are for the SELECTED MONTH (recomputed client-side), and the
/// month is shown directly under the headline as "YYYY년 M월 기준".
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.month});

  final MonthlyAttendanceStats stats;
  final AttendanceMonth month;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppProgressRing(
                value: stats.attendanceRate.clamp(0.0, 1.0),
                size: 112,
                label: '출석률',
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeadlineStat(
                      label: '수업일',
                      value: '${stats.totalDays}일',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HeadlineStat(
                      label: '환산 결석',
                      value: '${stats.computedAbsent}회',
                      emphasizeDanger: stats.computedAbsent > 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 기준 달을 요약 바로 아래에 명확히 표기.
          Text(
            '${month.label} 기준',
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _TypeCountChip(
                type: AttendanceType.present,
                count: stats.present,
                tone: StatusTone.success,
              ),
              _TypeCountChip(
                type: AttendanceType.late,
                count: stats.late,
                tone: StatusTone.warning,
              ),
              _TypeCountChip(
                type: AttendanceType.absent,
                count: stats.absent,
                tone: StatusTone.danger,
              ),
              _TypeCountChip(
                type: AttendanceType.earlyLeave,
                count: stats.earlyLeave,
                tone: StatusTone.warning,
              ),
              _TypeCountChip(
                type: AttendanceType.medical,
                count: stats.medical,
                tone: StatusTone.info,
              ),
              _TypeCountChip(
                type: AttendanceType.official,
                count: stats.official,
                tone: StatusTone.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A label + large value pair used in the summary card.
class _HeadlineStat extends StatelessWidget {
  const _HeadlineStat({
    required this.label,
    required this.value,
    this.emphasizeDanger = false,
  });

  final String label;
  final String value;
  final bool emphasizeDanger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.headlineSm.copyWith(
            color: emphasizeDanger ? AppColors.error : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// A `유형 N회` chip with a semantic tone.
class _TypeCountChip extends StatelessWidget {
  const _TypeCountChip({
    required this.type,
    required this.count,
    required this.tone,
  });

  final AttendanceType type;
  final int count;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return StatusChip(label: '${type.label} $count회', tone: tone);
  }
}

/// Per-date EXCEPTION list (newest first).
class _RecordList extends StatelessWidget {
  const _RecordList({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final record in records) ...[
          _RecordTile(record: record),
          if (record != records.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// One exception row: date + reason label + status chip + "문서 제출" button.
///
/// The label under the date is the record's REASON/TYPE name (지각 / 결석 /
/// 조퇴 / 병결 / 공결), enriched with the late/early-leave minutes or the note
/// when present — never a "---" placeholder.
///
/// Tapping 제출 navigates to the leave-request form pre-filled with this row's
/// date, the mapped leave type, and (for 조퇴) the leave time derived from the
/// record. Prefill travels as QUERY PARAMS so a web reload preserves it.
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final AttendanceRecord record;

  StatusTone get _tone {
    switch (record.type) {
      case AttendanceType.present:
        return StatusTone.success;
      case AttendanceType.late:
      case AttendanceType.earlyLeave:
        return StatusTone.warning;
      case AttendanceType.absent:
        return StatusTone.danger;
      case AttendanceType.medical:
      case AttendanceType.official:
        return StatusTone.info;
      case AttendanceType.unknown:
        return StatusTone.neutral;
    }
  }

  /// The reason/type label shown under the date. Starts from the type name and
  /// appends concrete detail (minutes or note) when the record carries it.
  String get _reasonLabel {
    final base = record.type.label;
    if (record.lateMinutes != null && record.lateMinutes! > 0) {
      return '$base · ${record.lateMinutes}분';
    }
    if (record.earlyLeaveMinutes != null && record.earlyLeaveMinutes! > 0) {
      return '$base · ${record.earlyLeaveMinutes}분';
    }
    if (record.note != null && record.note!.isNotEmpty) {
      return '$base · ${record.note}';
    }
    return base;
  }

  /// Maps the attendance type to the best-matching leave-request type so the
  /// form opens on the right tab. early_leave/official map directly; late/
  /// absent/medical default to 병결 (the most common justifying document).
  LeaveType get _leaveType {
    switch (record.type) {
      case AttendanceType.earlyLeave:
        return LeaveType.earlyLeave;
      case AttendanceType.official:
        return LeaveType.official;
      case AttendanceType.medical:
      case AttendanceType.late:
      case AttendanceType.absent:
      case AttendanceType.present:
      case AttendanceType.unknown:
        return LeaveType.medical;
    }
  }

  /// For 조퇴 rows, derive the leave time from the recorded check-out (falling
  /// back to nothing — the student can pick it on the form).
  TimeOfDayValue? get _startTime {
    if (_leaveType != LeaveType.earlyLeave) return null;
    final out = record.checkOutAt?.toLocal();
    if (out == null) return null;
    return TimeOfDayValue(out.hour, out.minute);
  }

  void _submitDocument(BuildContext context) {
    final query = LeaveFormPrefill.toQuery(
      type: _leaveType,
      targetDate: record.date,
      startTime: _startTime,
    );
    final uri = Uri(
      path: '/student/leave-requests/new',
      queryParameters: query,
    );
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormatter.date(record.date),
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _reasonLabel,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(label: record.type.label, tone: _tone),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: isMobile ? '제출' : '문서 제출',
            icon: Icons.upload_file_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _submitDocument(context),
          ),
        ],
      ),
    );
  }
}

/// Inline loading block (used per section so each region can load independently).
class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: LoadingView(message: message),
    );
  }
}

/// Inline error block with retry (used per section).
class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: ErrorView(message: message, onRetry: onRetry),
    );
  }
}

/// Summary empty state: the selected month has no attendance records.
class _SummaryEmpty extends StatelessWidget {
  const _SummaryEmpty({required this.month});

  final AttendanceMonth month;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: EmptyState(
        title: '${month.label} 출결 기록이 없습니다',
        description: '선택한 달에 집계할 출결 기록이 없습니다.',
        icon: Icons.insights_outlined,
      ),
    );
  }
}

/// Per-month exceptions empty state.
class _RecordsEmpty extends StatelessWidget {
  const _RecordsEmpty();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: EmptyState(
        title: '이 달의 특이사항이 없습니다',
        description: '선택한 달에는 지각·결석·조퇴·병결·공결 기록이 없습니다.',
        icon: Icons.event_available_outlined,
      ),
    );
  }
}
