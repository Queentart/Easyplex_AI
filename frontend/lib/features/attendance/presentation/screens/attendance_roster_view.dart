import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/attendance_model.dart';
import '../../domain/attendance_roster.dart';
import '../attendance_management_provider.dart';
import '../attendance_provider.dart' show AttendanceMonth;

/// Reusable STANDARD attendance MANAGEMENT view (roster-centric).
///
/// Used by both the operations-team and instructor management screens. Renders:
///   - top controls: an optional cohort field/selector + month navigation +
///     a roster sort dropdown,
///   - overall period stats (전체 출석률 / 인원수 / 지각·결석 합계),
///   - a per-student roster table (one row per student) with at-risk rows
///     highlighted; tapping a row opens that student's daily-record sheet.
///
/// The owning screen supplies the already-loaded [roster] for the selected
/// period and the [trailingControls] (e.g. a cohort filter field or a "CSV
/// 가져오기" action) so this widget stays presentation-only and reusable.
class AttendanceRosterView extends ConsumerWidget {
  const AttendanceRosterView({
    super.key,
    required this.roster,
    required this.month,
    required this.onSelectMonth,
    this.leadingControls = const [],
    this.trailingControls = const [],
    this.recordActionBuilder,
  });

  final AttendanceRoster roster;
  final AttendanceMonth month;
  final ValueChanged<AttendanceMonth> onSelectMonth;

  /// Controls rendered at the START of the control bar (e.g. a cohort filter).
  final List<Widget> leadingControls;

  /// Controls rendered at the END of the control bar (e.g. a "CSV 가져오기"
  /// action).
  final List<Widget> trailingControls;

  /// Optional per-record action widget for the drill-down detail sheet (e.g.
  /// the instructor's 정정/알림 buttons). When null, records are read-only.
  final Widget Function(BuildContext context, AttendanceRecord record)?
      recordActionBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(rosterSortProvider);
    final students = roster.sorted(sort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 상단 컨트롤 (기수 / 기간 / 정렬) ─────────────────────────────
        AppCard(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...leadingControls,
              _MonthNavigator(month: month, onSelect: onSelectMonth),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<RosterSort>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: '정렬'),
                  items: [
                    for (final s in RosterSort.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (s) {
                    if (s != null) {
                      ref.read(rosterSortProvider.notifier).select(s);
                    }
                  },
                ),
              ),
              ...trailingControls,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── 전체 요약 통계 ───────────────────────────────────────────────
        _SummaryStats(month: month, summary: roster.summary),
        const SizedBox(height: AppSpacing.lg),

        // ── 수강생별 로스터 ──────────────────────────────────────────────
        Text('수강생별 출결', style: AppTypography.headlineSm),
        const SizedBox(height: AppSpacing.md),
        if (students.isEmpty)
          const AppCard(
            child: EmptyState(
              title: '이 기간의 출결 기록이 없습니다',
              description: '기수 또는 기간을 변경하거나 CSV로 출결을 가져오세요.',
              icon: Icons.event_busy_outlined,
            ),
          )
        else
          _RosterTable(
            students: students,
            recordActionBuilder: recordActionBuilder,
          ),
      ],
    );
  }
}

/// Overall period stats: 전체 출석률 + 인원수 + 지각/결석 합계 + 주의/위험 인원.
class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.month, required this.summary});

  final AttendanceMonth month;
  final AttendanceRosterSummary summary;

  @override
  Widget build(BuildContext context) {
    final ratePct = (summary.overallRate * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${month.label} 기준',
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('전체 출석률',
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('$ratePct%', style: AppTypography.headlineMd),
                    const SizedBox(height: AppSpacing.sm),
                    AppProgressBar(
                      value: summary.overallRate.clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(label: '인원 ${summary.studentCount}명'),
              StatusChip(
                label: '지각 ${summary.lateTotal}',
                tone: StatusTone.warning,
              ),
              StatusChip(
                label: '결석 ${summary.absentTotal}',
                tone: StatusTone.danger,
              ),
              StatusChip(
                label: '주의·위험 ${summary.atRiskCount}명',
                tone: summary.atRiskCount > 0
                    ? StatusTone.danger
                    : StatusTone.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Month navigation: prev / next chevrons around a tappable month dropdown.
/// "Next" is disabled once the selected month reaches the current month.
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

/// Per-student roster table. One row per student; at-risk rows highlighted.
/// Tapping a row opens that student's daily-record detail sheet.
class _RosterTable extends StatelessWidget {
  const _RosterTable({required this.students, this.recordActionBuilder});

  final List<StudentAttendanceRoster> students;
  final Widget Function(BuildContext context, AttendanceRecord record)?
      recordActionBuilder;

  StatusTone _tierTone(RiskTier tier) {
    switch (tier) {
      case RiskTier.normal:
        return StatusTone.success;
      case RiskTier.warning:
        return StatusTone.warning;
      case RiskTier.danger:
        return StatusTone.danger;
    }
  }

  void _openDetail(BuildContext context, StudentAttendanceRoster student) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _StudentDetailSheet(
        student: student,
        recordActionBuilder: recordActionBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      columns: const ['이름', '출석', '지각', '결석', '조퇴/기타', '출석률', '상태'],
      columnFlex: const [4, 2, 2, 2, 3, 3, 2],
      rows: [
        for (final s in students)
          AppTableRow(
            highlight: s.isAtRisk,
            cells: [
              // 이름 (tappable → drill-down)
              InkWell(
                onTap: () => _openDetail(context, s),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.displayName,
                        style: AppTypography.bodySm
                            .copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
              Text('${s.present}일'),
              Text('${s.late}'),
              Text('${s.absent}'),
              Text('${s.otherCount}'),
              Text(
                '${(s.attendanceRate * 100).round()}%',
                style: AppTypography.bodySm
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: s.tier.label,
                  tone: _tierTone(s.tier),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Drill-down detail: one student's per-date records for the period.
class _StudentDetailSheet extends StatelessWidget {
  const _StudentDetailSheet({
    required this.student,
    this.recordActionBuilder,
  });

  final StudentAttendanceRoster student;
  final Widget Function(BuildContext context, AttendanceRecord record)?
      recordActionBuilder;

  StatusTone _toneFor(AttendanceType type) {
    switch (type) {
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

  String? _detail(AttendanceRecord r) {
    if (r.lateMinutes != null && r.lateMinutes! > 0) {
      return '지각 ${r.lateMinutes}분';
    }
    if (r.earlyLeaveMinutes != null && r.earlyLeaveMinutes! > 0) {
      return '조퇴 ${r.earlyLeaveMinutes}분';
    }
    if (r.note != null && r.note!.isNotEmpty) return r.note;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + media.viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(student.displayName,
                      style: AppTypography.headlineSm),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '출석률 ${(student.attendanceRate * 100).round()}% · '
              '출석 ${student.present}일 · 지각 ${student.late} · '
              '결석 ${student.absent} · 환산 결석 ${student.computedAbsent}',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('일자별 기록', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: student.records.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: EmptyState(
                        title: '기록이 없습니다',
                        description: '이 기간에는 출결 기록이 없습니다.',
                        icon: Icons.event_available_outlined,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: student.records.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (sheetContext, i) {
                        final r = student.records[i];
                        final detail = _detail(r);
                        final action = recordActionBuilder?.call(sheetContext, r);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormatter.date(r.date),
                                        style: AppTypography.bodyMd.copyWith(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (detail != null) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          detail,
                                          style: AppTypography.bodySm.copyWith(
                                              color:
                                                  AppColors.onSurfaceVariant),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                StatusChip(
                                  label: r.type.label,
                                  tone: _toneFor(r.type),
                                ),
                              ],
                            ),
                            if (action != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: action,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
