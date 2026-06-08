/// INSTRUCTOR home dashboard (aggregated).
///
/// Replaces the placeholder with a real overview built ENTIRELY from existing
/// feature providers (no new data layer). Each card watches its own provider so
/// a single failing card degrades to an inline error + retry without blocking
/// the rest of the page. Tapping a card routes to the owning feature.
///
/// Cards:
///   1. 담당 기수 출결 요약 + 지각/결석 경고  (attendance)        → /instructor/attendance
///   2. 과제 제출 현황 (제출률 progress)        (assignment)        → /instructor/assignments
///   3. 멘토링/상담 최근 기록                    (mentoring)         → /instructor/counseling
///   4. 오늘/예정 수업                           (class_)            → /instructor/classes
///   5. AI 코파일럿 진입 카드                     (ai_agent)          → /instructor/ai
///
/// Design-system tokens / components only — no hardcoded colors / magic
/// numbers. Tablet/PC-first (operations-side), gracefully degrading to a single
/// column on mobile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
// Reused, read-only feature providers (data layers are NOT rebuilt here).
import '../../../assignment/domain/assignment_model.dart';
import '../../../assignment/presentation/grading_provider.dart';
import '../../../attendance/domain/attendance_model.dart';
import '../../../attendance/presentation/instructor_attendance_provider.dart';
import '../../../class_/domain/class_model.dart';
import '../../../class_/presentation/class_provider.dart';
import '../../../mentoring/domain/mentoring_model.dart';
import '../../../mentoring/presentation/mentoring_provider.dart';
import '../instructor_dashboard_provider.dart';

/// Route paths the cards navigate to (kept local — the router owns the wiring).
const _attendanceRoute = '/instructor/attendance';
const _assignmentsRoute = '/instructor/assignments';
const _counselingRoute = '/instructor/counseling';
const _classesRoute = '/instructor/courses';
const _aiRoute = '/instructor/ai';

/// Instructor home dashboard.
class InstructorDashboardPage extends ConsumerWidget {
  const InstructorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentUserProvider)?.name ?? '강사';
    final cohortId = ref.watch(instructorCohortIdProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingHeader(name: name),
              const SizedBox(height: AppSpacing.lg),
              if (cohortId == null)
                const _NoCohortCard()
              else
                _DashboardGrid(cohortId: cohortId),
              const SizedBox(height: AppSpacing.lg),
              // AI co-pilot entry is always available to the instructor.
              const _AiCopilotCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// ── Greeting header ─────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('안녕하세요, $name 강사님', style: AppTypography.headlineLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '오늘 담당 기수의 현황을 한눈에 확인하세요.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// ── Responsive card grid ────────────────────────────────────────────────────

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.cohortId});

  final int cohortId;

  /// Vertically stacks [cards] with consistent [AppSpacing.lg] gaps.
  static Widget _stack(List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i != 0) const SizedBox(height: AppSpacing.lg),
          cards[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = _AttendanceSummaryCard(cohortId: cohortId);
    const assignments = _AssignmentProgressCard();
    const mentoring = _MentoringRecentCard();
    const classes = _UpcomingClassesCard();

    return ResponsiveLayout(
      // Mobile: single column, stacked.
      mobile: (_) => _stack([attendance, assignments, mentoring, classes]),
      // Tablet / desktop: two balanced columns.
      tablet: (_) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _stack([attendance, mentoring])),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _stack([assignments, classes])),
        ],
      ),
    );
  }
}

/// A consistent card shell: title row (icon + title + "전체 보기"), then body.
/// The whole card is tappable → routes to [route].
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.route,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.headlineSm)),
              Text(
                '전체 보기',
                style: AppTypography.labelSm.copyWith(color: AppColors.primary),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Compact inline error used inside a card body (keeps the card chrome).
class _CardError extends StatelessWidget {
  const _CardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ErrorView(
        message: '정보를 불러오지 못했습니다.',
        onRetry: onRetry,
      ),
    );
  }
}

/// Compact inline loader used inside a card body.
class _CardLoading extends StatelessWidget {
  const _CardLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: LoadingView(message: message),
    );
  }
}

/// ── Card 1: 담당 기수 출결 요약 + 지각/결석 경고 ───────────────────────────────

class _AttendanceSummaryCard extends ConsumerWidget {
  const _AttendanceSummaryCard({required this.cohortId});

  final int cohortId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(instructorCohortSummaryProvider(cohortId));

    return _DashboardCard(
      icon: Icons.fact_check_outlined,
      title: '담당 기수 출결 요약',
      route: _attendanceRoute,
      child: async.when(
        loading: () => const _CardLoading(message: '출결 요약을 불러오는 중입니다'),
        error: (_, _) => _CardError(
          onRetry: () => ref
              .read(instructorCohortSummaryProvider(cohortId).notifier)
              .refresh(),
        ),
        data: (summary) => _AttendanceSummaryBody(summary: summary),
      ),
    );
  }
}

class _AttendanceSummaryBody extends StatelessWidget {
  const _AttendanceSummaryBody({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final warnings = AttendanceWarnings.from(summary);
    final rate = summary.attendanceRate.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('출석률', style: AppTypography.labelSm),
            const Spacer(),
            Text('${(rate * 100).round()}%', style: AppTypography.labelMd),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(value: rate),
        const SizedBox(height: AppSpacing.md),
        // Per-type counts.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _CountChip(label: AttendanceType.present.label, count: summary.present),
            _CountChip(label: AttendanceType.late.label, count: summary.late),
            _CountChip(label: AttendanceType.absent.label, count: summary.absent),
          ],
        ),
        if (warnings.hasWarnings) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '지각 ${warnings.late}건 · 결석 ${warnings.absent}건'
                    ' (환산 결석 ${warnings.computedAbsent}회)',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onWarningContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.labelSm),
          const SizedBox(width: AppSpacing.sm),
          Text('$count', style: AppTypography.labelMd),
        ],
      ),
    );
  }
}

/// ── Card 2: 과제 제출 현황 ─────────────────────────────────────────────────────

class _AssignmentProgressCard extends ConsumerWidget {
  const _AssignmentProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gradingAssignmentsProvider);

    return _DashboardCard(
      icon: Icons.assignment_turned_in_outlined,
      title: '과제 제출 현황',
      route: _assignmentsRoute,
      child: async.when(
        loading: () => const _CardLoading(message: '과제를 불러오는 중입니다'),
        error: (_, _) => _CardError(
          onRetry: () => ref.read(gradingAssignmentsProvider.notifier).refresh(),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return Text(
              '등록된 과제가 없습니다. 과제를 등록하면 제출 현황이 표시됩니다.',
              style:
                  AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            );
          }
          // Most-recent few assignments, each with its own submission progress.
          final recent = assignments.take(3).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i != 0) const SizedBox(height: AppSpacing.md),
                _AssignmentProgressRow(assignment: recent[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AssignmentProgressRow extends ConsumerWidget {
  const _AssignmentProgressRow({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(submissionRowsProvider(assignment.id));

    return async.when(
      loading: () => _AssignmentRowShell(
        assignment: assignment,
        trailing: const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        progress: 0,
        caption: '집계 중…',
      ),
      error: (_, _) => _AssignmentRowShell(
        assignment: assignment,
        progress: 0,
        caption: '제출 현황을 불러오지 못했습니다',
        captionTone: AppColors.error,
      ),
      data: (rows) {
        final submitted = rows.length;
        final graded =
            rows.where((r) => r.status == SubmissionStatus.reviewed).length;
        final progress = submitted == 0 ? 0.0 : graded / submitted;
        return _AssignmentRowShell(
          assignment: assignment,
          progress: progress,
          caption: '제출 $submitted건 · 평가 완료 $graded건',
        );
      },
    );
  }
}

class _AssignmentRowShell extends StatelessWidget {
  const _AssignmentRowShell({
    required this.assignment,
    required this.progress,
    required this.caption,
    this.trailing,
    this.captionTone,
  });

  final Assignment assignment;
  final double progress;
  final String caption;
  final Widget? trailing;
  final Color? captionTone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                assignment.title,
                style: AppTypography.labelMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (trailing != null)
              trailing!
            else
              Text('${(progress * 100).round()}%', style: AppTypography.labelSm),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(value: progress.clamp(0.0, 1.0)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          caption,
          style: AppTypography.labelSm.copyWith(
            color: captionTone ?? AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// ── Card 3: 멘토링/상담 최근 기록 ──────────────────────────────────────────────

class _MentoringRecentCard extends ConsumerWidget {
  const _MentoringRecentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mentoringLogListProvider);

    return _DashboardCard(
      icon: Icons.psychology_outlined,
      title: '멘토링·상담 최근 기록',
      route: _counselingRoute,
      child: async.when(
        loading: () => const _CardLoading(message: '상담 기록을 불러오는 중입니다'),
        error: (_, _) => _CardError(
          onRetry: () => ref.read(mentoringLogListProvider.notifier).refresh(),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Text(
              '최근 상담 기록이 없습니다. 상담을 진행하면 이곳에 표시됩니다.',
              style:
                  AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            );
          }
          final recent = logs.take(3).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i != 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _MentoringRow(log: recent[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MentoringRow extends StatelessWidget {
  const _MentoringRow({required this.log});

  final MentoringLog log;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.content,
                style: AppTypography.bodySm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '상담일 ${DateFormatter.date(log.sessionDate)}',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (log.hasFollowUp) ...[
          const SizedBox(width: AppSpacing.sm),
          const StatusChip(label: '후속 조치', tone: StatusTone.info),
        ],
      ],
    );
  }
}

/// ── Card 4: 오늘/예정 수업 ─────────────────────────────────────────────────────

class _UpcomingClassesCard extends ConsumerWidget {
  const _UpcomingClassesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classListProvider);

    return _DashboardCard(
      icon: Icons.event_available_outlined,
      title: '오늘·예정 수업',
      route: _classesRoute,
      child: async.when(
        loading: () => const _CardLoading(message: '수업을 불러오는 중입니다'),
        error: (_, _) => _CardError(
          onRetry: () => ref.read(classListProvider.notifier).refresh(),
        ),
        data: (classes) {
          final upcoming = _upcoming(classes);
          if (upcoming.isEmpty) {
            return Text(
              '예정된 수업이 없습니다. 수업이 배정되면 이곳에 표시됩니다.',
              style:
                  AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < upcoming.length; i++) ...[
                if (i != 0) const SizedBox(height: AppSpacing.sm),
                _ClassRow(session: upcoming[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Today-and-later, non-cancelled sessions, soonest first (max 3).
  List<ClassSession> _upcoming(List<ClassSession> classes) {
    final startOfToday = DateTime.now();
    final cutoff =
        DateTime(startOfToday.year, startOfToday.month, startOfToday.day);
    final filtered = classes
        .where((c) => !c.isCancelled && !c.date.toLocal().isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return filtered.take(3).toList();
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.session});

  final ClassSession session;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(session.date.toLocal(), DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.title,
                style: AppTypography.labelMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  DateFormatter.date(session.date),
                  if (session.timeRange.isNotEmpty) session.timeRange,
                ].join(' · '),
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (isToday) ...[
          const SizedBox(width: AppSpacing.sm),
          const StatusChip(label: '오늘', tone: StatusTone.success),
        ],
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// ── Card 5: AI 코파일럿 진입 ───────────────────────────────────────────────────

class _AiCopilotCard extends StatelessWidget {
  const _AiCopilotCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      hero: true,
      onTap: () => context.go(_aiRoute),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 28, color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 코파일럿', style: AppTypography.headlineSm),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '출결·과제·상담 데이터를 바탕으로 질문하고 보고서 작성을 도와드립니다.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            label: '열기',
            icon: Icons.arrow_forward_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.go(_aiRoute),
          ),
        ],
      ),
    );
  }
}

/// ── Empty state: instructor has no cohort ─────────────────────────────────────

class _NoCohortCard extends StatelessWidget {
  const _NoCohortCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 48, color: AppColors.outline),
          const SizedBox(height: AppSpacing.md),
          Text('아직 담당 기수가 없습니다', style: AppTypography.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '운영팀이 기수를 배정하면 출결·과제·상담 현황이 이곳에 표시됩니다.\n'
            '그동안에도 AI 코파일럿은 사용할 수 있습니다.',
            textAlign: TextAlign.center,
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
