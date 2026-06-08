import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../mentoring/domain/mentoring_model.dart';
import '../../../mentoring/presentation/mentoring_provider.dart';
import '../student_counseling_provider.dart';

/// 수강생 상담 화면.
///
/// Counseling is STUDENT-INITIATED here. Two sections:
///
///   1. 상담 신청 (REAL, student writes) — the student REQUESTS counseling. We
///      submit it as an inquiry via `POST /inquiries/` (type `operation` → "운영
///      문의") through [counselingRequestProvider]. Students hold `inquiry.create`;
///      `POST /mentoring-logs` is instructor-only, so the realistic write path
///      for a student is an inquiry. The request is routed to the operations
///      team / instructor.
///
///   2. 내 상담 기록 (READ ONLY) — the counseling / mentoring records that the
///      INSTRUCTOR wrote about this student, as a timeline.
///      `GET /mentoring-logs` is guarded only by `get_current_user`, and the
///      service auto-scopes a student to `MentoringLog.student_id == self.id`
///      (see `backend/app/services/class_.py::list_mentoring_logs`). We reuse
///      [mentoringLogListProvider] verbatim (read-only). Composing logs stays
///      instructor-only (server-enforced), so this section has no compose action.
///
/// Rendered inside the authenticated app shell, so this returns scrollable page
/// content only (no Scaffold / AppBar of its own — matching
/// [StudentSupportScreen] and `StudentDashboardPage`).
class StudentCounselingScreen extends ConsumerStatefulWidget {
  const StudentCounselingScreen({super.key});

  @override
  ConsumerState<StudentCounselingScreen> createState() =>
      _StudentCounselingScreenState();
}

class _StudentCounselingScreenState
    extends ConsumerState<StudentCounselingScreen> {
  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(mentoringLogListProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(mentoringLogListProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.md),
            const _ChannelInfoBanner(),
            const SizedBox(height: AppSpacing.lg),
            // Section 1 — 상담 신청 (student writes the request).
            const _CounselingRequestCard(),
            const SizedBox(height: AppSpacing.lg),
            // Section 2 — 내 상담 기록 (instructor-authored, read-only).
            _RecordsSection(state: logsState),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('상담', style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '상담이 필요하면 직접 신청할 수 있어요. '
          '아래에서는 강사님이 작성한 상담 기록을 확인할 수 있습니다.',
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Privacy-emphasizing banner that distinguishes 상담(counseling) from 내문의.
/// Counseling is a PRIVATE channel visible only to the assigned instructor —
/// for personal / learning / career concerns. Administrative or technical
/// problems belong in 내 문의 (운영·지원팀 tickets).
class _ChannelInfoBanner extends StatelessWidget {
  const _ChannelInfoBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '담당 강사에게만 공개되는 개인 상담 공간입니다.',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '학습·진로·생활 등 개인적인 고민을 편하게 남겨보세요. '
                  '행정·기술 문제는 «내 문의»로 접수해 주세요.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Section 1 — 상담 신청 (REAL: POST /inquiries/, type=operation)
/// ─────────────────────────────────────────────────────────────────────────

class _CounselingRequestCard extends ConsumerStatefulWidget {
  const _CounselingRequestCard();

  @override
  ConsumerState<_CounselingRequestCard> createState() =>
      _CounselingRequestCardState();
}

class _CounselingRequestCardState
    extends ConsumerState<_CounselingRequestCard> {
  final _topicCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();

  @override
  void dispose() {
    _topicCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(counselingRequestProvider);
    final notifier = ref.read(counselingRequestProvider.notifier);

    // React to create-success / error once each.
    ref.listen<CounselingRequestState>(counselingRequestProvider, (prev, next) {
      if (next.created != null && prev?.created == null) {
        // Reset the local controllers (notifier already cleared its fields).
        _topicCtrl.clear();
        _detailCtrl.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('상담 신청이 접수되었습니다. 운영팀·강사님이 확인 후 연락드립니다.'),
            ),
          );
        notifier.acknowledgeCreated();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return AppSectionCard(
      title: '상담 신청',
      icon: Icons.support_agent_outlined,
      trailing: const StatusChip(label: '운영팀·강사 전달', tone: StatusTone.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '학습·진로·생활 등 상담받고 싶은 내용을 남기면 운영팀·강사님에게 전달돼요.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('상담 주제'),
          TextField(
            controller: _topicCtrl,
            maxLength: 200,
            enabled: !form.isSubmitting,
            decoration: const InputDecoration(
              hintText: '예: 진로 상담을 받고 싶어요',
            ),
            onChanged: notifier.setTopic,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FieldLabel('상담 내용'),
          TextField(
            controller: _detailCtrl,
            minLines: 5,
            maxLines: 10,
            enabled: !form.isSubmitting,
            decoration: const InputDecoration(
              hintText: '상담받고 싶은 내용이나 상황을 자세히 적어주세요',
            ),
            onChanged: notifier.setDetail,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '상담 신청하기',
            icon: Icons.send_rounded,
            expand: true,
            loading: form.isSubmitting,
            onPressed: form.isValid ? notifier.submit : null,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Section 2 — 내 상담 기록 (READ ONLY: GET /mentoring-logs, self-scoped)
/// ─────────────────────────────────────────────────────────────────────────

class _RecordsSection extends ConsumerWidget {
  const _RecordsSection({required this.state});

  final AsyncValue<List<MentoringLog>> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSectionCard(
      title: '내 상담 기록',
      icon: Icons.event_note_outlined,
      trailing: const StatusChip(label: '강사 작성 · 읽기 전용', tone: StatusTone.info),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '강사님이 작성한 상담·멘토링 기록을 최신순으로 확인할 수 있어요. 기록은 직접 수정할 수 없습니다.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          state.when(
            loading: () => const _Pane(
              child: LoadingView(message: '상담 기록을 불러오는 중입니다.'),
            ),
            error: (e, _) => _Pane(
              child: ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.read(mentoringLogListProvider.notifier).refresh(),
              ),
            ),
            data: (logs) => logs.isEmpty
                ? const _Pane(
                    child: EmptyState(
                      icon: Icons.event_note_outlined,
                      title: '상담 기록이 없습니다',
                      description: '아직 강사님이 작성한 상담 기록이 없어요.\n'
                          '상담이 진행되면 이곳에서 내용과 후속 조치를 확인할 수 있습니다.',
                    ),
                  )
                : _CounselingTimeline(logs: logs),
          ),
        ],
      ),
    );
  }
}

/// Gives placeholder content (loading / error / empty) a comfortable height
/// inside the section card.
class _Pane extends StatelessWidget {
  const _Pane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(child: child),
    );
  }
}

/// Read-only vertical timeline of counseling records (newest first).
class _CounselingTimeline extends StatelessWidget {
  const _CounselingTimeline({required this.logs});

  final List<MentoringLog> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < logs.length; i++)
          _TimelineEntry(
            log: logs[i],
            isLast: i == logs.length - 1,
          ),
      ],
    );
  }
}

/// One timeline row: a date marker rail on the left, a record card on the right.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.log, required this.isLast});

  final MentoringLog log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rail(isLast: isLast),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: _RecordCard(log: log),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dot + connector line drawn to the left of each timeline card.
class _Rail extends StatelessWidget {
  const _Rail({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.onPrimary, width: 2),
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(
              width: 2,
              color: AppColors.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// A single counseling record rendered as a card (date, content, follow-up).
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.log});

  final MentoringLog log;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_note_outlined,
                size: 18,
                color: AppColors.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '상담일 ${DateFormatter.date(log.sessionDate)}',
                  style: AppTypography.headlineSm,
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

/// ─────────────────────────────────────────────────────────────────────────
/// Shared bits
/// ─────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style:
            AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
