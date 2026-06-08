import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/list_header.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../instructor/presentation/instructor_dashboard_provider.dart';
import '../../domain/mentoring_model.dart';
import '../mentoring_provider.dart';

/// Instructor mentoring / counseling records screen.
///
/// Lists the instructor's own counseling logs (newest session first) and lets
/// them record a new session via a bottom sheet. Tablet/PC-first, mobile-aware.
/// Renders inside the authenticated [AppShell], which supplies the top bar.
class MentoringLogScreen extends ConsumerWidget {
  const MentoringLogScreen({super.key});

  static const String routePath = '/instructor/counseling';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Instructors link to cohorts via the join table (cohortId is null); resolve
    // the active taught cohort to seed the compose sheet.
    final cohortId = ref.watch(instructorCohortIdProvider);
    final state = ref.watch(mentoringLogListProvider);

    // Composing a log is an instructor-only action (also server-enforced).
    final canCreate = user?.role == 'instructor';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(
            title: '상담 기록',
            action: canCreate
                ? AppButton(
                    label: '상담 기록',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () => _openComposeSheet(context, ref, cohortId),
                  )
                : null,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(mentoringLogListProvider.notifier).refresh(),
              child: state.when(
          loading: () => const LoadingView(message: '상담 기록을 불러오는 중입니다.'),
          error: (e, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(mentoringLogListProvider.notifier).refresh(),
                ),
              ),
            ],
          ),
          data: (logs) => logs.isEmpty
              ? const _EmptyLogs()
              : _LogList(logs: logs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openComposeSheet(
    BuildContext context,
    WidgetRef ref,
    int? cohortId,
  ) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _MentoringComposeSheet(cohortId: cohortId),
    );

    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상담 기록이 저장되었습니다.')),
      );
    }
  }
}

/// Empty-state guidance. The compose CTA lives in the persistent header.
class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(
            child: EmptyState(
              icon: Icons.support_agent_outlined,
              title: '상담 기록이 없습니다',
              description: '수강생과의 상담·멘토링 내용을 기록으로 남겨보세요.',
            ),
          ),
        ),
      ],
    );
  }
}

/// Scrollable list of counseling records.
class _LogList extends StatelessWidget {
  const _LogList({required this.logs});

  final List<MentoringLog> logs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _LogCard(log: logs[i]),
    );
  }
}

/// A single counseling record card.
class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final MentoringLog log;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '수강생 #${log.studentId}',
                      style: AppTypography.headlineSm,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '상담일 ${DateFormatter.date(log.sessionDate)}',
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (log.hasFollowUp)
                const StatusChip(
                  label: '후속 조치',
                  tone: StatusTone.info,
                  icon: Icons.flag_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(log.content, style: AppTypography.bodyMd),
          if (log.hasFollowUp) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '후속 조치',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(log.followUp!, style: AppTypography.bodySm),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom-sheet form for recording a new counseling session.
///
/// Pops `true` once the log is saved so the caller can show a confirmation.
class _MentoringComposeSheet extends ConsumerWidget {
  const _MentoringComposeSheet({required this.cohortId});

  final int? cohortId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(mentoringFormProvider(cohortId));
    final notifier = ref.read(mentoringFormProvider(cohortId).notifier);
    final studentsAsync = ref.watch(cohortStudentsProvider(cohortId));

    // Show feedback + close once the submission succeeds.
    ref.listen(mentoringFormProvider(cohortId), (prev, next) {
      if (next.isSuccess && (prev == null || !prev.isSuccess)) {
        Navigator.of(context).pop(true);
      }
    });

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('상담 기록 작성',
                        style: AppTypography.headlineMd),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Student picker ─────────────────────────────────────────
              Text('대상 수강생',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              studentsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => _InlineError(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(cohortStudentsProvider(cohortId)),
                ),
                data: (students) => _StudentDropdown(
                  students: students,
                  value: form.studentId,
                  onChanged: notifier.setStudent,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Session date ───────────────────────────────────────────
              Text('상담일',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              _DateField(
                date: form.sessionDate,
                onPick: notifier.setSessionDate,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Content ────────────────────────────────────────────────
              Text('상담 내용',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                minLines: 4,
                maxLines: 8,
                onChanged: notifier.setContent,
                decoration: const InputDecoration(
                  hintText: '상담 시 나눈 이야기와 관찰 내용을 입력하세요.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Follow-up (optional) ───────────────────────────────────
              Text('후속 조치 (선택)',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                minLines: 2,
                maxLines: 4,
                onChanged: notifier.setFollowUp,
                decoration: const InputDecoration(
                  hintText: '필요한 후속 조치나 다음 상담 계획을 입력하세요.',
                ),
              ),

              if (form.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  form.error!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: '저장',
                icon: Icons.save_outlined,
                expand: true,
                loading: form.isSubmitting,
                onPressed: form.isValid ? notifier.submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown of cohort students (subject of the counseling session).
class _StudentDropdown extends StatelessWidget {
  const _StudentDropdown({
    required this.students,
    required this.value,
    required this.onChanged,
  });

  final List<CohortStudent> students;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Text(
        '기수에 등록된 수강생이 없습니다.',
        style:
            AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(hintText: '수강생을 선택하세요'),
      items: [
        for (final s in students)
          DropdownMenuItem(
            value: s.id,
            child: Text('${s.name} (${s.email})',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Tappable date field that opens a date picker.
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});

  final DateTime? date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final label = date == null ? '날짜 선택' : DateFormatter.date(date!);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: now,
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.outline),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppTypography.bodyMd),
          ],
        ),
      ),
    );
  }
}

/// Compact inline error with a retry affordance (used inside the sheet).
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySm.copyWith(color: AppColors.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}
