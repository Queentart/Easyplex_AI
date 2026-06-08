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
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/class_model.dart';
import '../class_provider.dart';
import 'class_list_screen.dart' show classStatusChip;

/// Student entry point for course evaluations: the list of the student's
/// classes (server-scoped to their cohort via `GET /classes`). Tapping a class
/// opens the anonymous evaluation form. Student-only — other roles see an
/// access-denied state.
class StudentEvaluationListScreen extends ConsumerWidget {
  const StudentEvaluationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user?.role != 'student') {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('강의평가'),
          backgroundColor: AppColors.surface,
        ),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: '접근 권한이 없습니다',
          description: '강의평가는 수강생만 작성할 수 있습니다.',
        ),
      );
    }

    final state = ref.watch(classListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('강의평가'),
        backgroundColor: AppColors.surface,
      ),
      body: state.when(
        loading: () => const LoadingView(message: '수업 목록을 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(classListProvider),
        ),
        data: (classes) => classes.isEmpty
            ? const EmptyState(
                icon: Icons.rate_review_outlined,
                title: '평가할 수업이 없습니다',
                description: '수업이 등록되면 이곳에서 강의평가를 작성할 수 있습니다.',
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(classListProvider.notifier).refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: classes.length,
                  separatorBuilder: (context, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _EvaluationClassCard(
                    session: classes[i],
                    onTap: () => context.push(
                      '/student/evaluations/${classes[i].id}',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EvaluationClassCard extends StatelessWidget {
  const _EvaluationClassCard({required this.session, required this.onTap});

  final ClassSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = classStatusChip(session.status);
    return AppCard(
      onTap: onTap,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusChip(label: chip.label, tone: chip.tone),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  DateFormatter.date(session.date),
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: AppColors.outline),
        ],
      ),
    );
  }
}

/// Anonymous course-evaluation form for a single class (student only).
///
/// Submits a 1–5 star [rating] plus an optional comment via
/// `POST /classes/{id}/evaluations`. The submission is anonymous to the
/// instructor — the student identity is never sent back through results. A
/// repeat submission returns `ALREADY_EVALUATED` (409), which is surfaced as a
/// friendly "이미 평가를 제출했습니다." state.
class ClassEvaluationFormScreen extends ConsumerStatefulWidget {
  const ClassEvaluationFormScreen({super.key, required this.classId});

  final int classId;

  @override
  ConsumerState<ClassEvaluationFormScreen> createState() =>
      _ClassEvaluationFormScreenState();
}

class _ClassEvaluationFormScreenState
    extends ConsumerState<ClassEvaluationFormScreen> {
  late final TextEditingController _comment;

  int get _classId => widget.classId;

  @override
  void initState() {
    super.initState();
    _comment = TextEditingController();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '평가를 제출하시겠습니까?',
      message: '제출 후에는 수정할 수 없으며, 강사에게는 익명으로 전달됩니다.',
      confirmLabel: '제출',
    );
    if (!confirmed) return;

    final notifier = ref.read(evaluationFormProvider(_classId).notifier);
    notifier.setComment(_comment.text);
    await notifier.submit();

    if (!mounted) return;
    final state = ref.read(evaluationFormProvider(_classId));
    if (state.isSuccess) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('강의평가를 제출했습니다. 감사합니다!')));
      if (context.canPop()) context.pop();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user?.role != 'student') {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('강의평가'),
          backgroundColor: AppColors.surface,
        ),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: '접근 권한이 없습니다',
          description: '강의평가는 수강생만 작성할 수 있습니다.',
        ),
      );
    }

    final formState = ref.watch(evaluationFormProvider(_classId));
    final notifier = ref.read(evaluationFormProvider(_classId).notifier);
    final alreadyEvaluated = formState.errorCode == 'ALREADY_EVALUATED';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('강의평가'),
        backgroundColor: AppColors.surface,
      ),
      body: alreadyEvaluated
          ? EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: '이미 평가를 제출했습니다',
              description: '이 수업에 대한 강의평가는 이미 제출되어 있습니다.',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 20, color: AppColors.outline),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '강의평가는 익명으로 전달됩니다. 강사에게 작성자 정보가 표시되지 않습니다.',
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('만족도', style: AppTypography.labelMd),
                          Text(' *',
                              style: AppTypography.labelMd
                                  .copyWith(color: AppColors.error)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _StarRating(
                        rating: formState.rating,
                        onChanged: notifier.setRating,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('의견', style: AppTypography.labelMd),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _comment,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: '수업에 대한 의견을 자유롭게 작성해주세요 (선택)',
                        ),
                        onChanged: notifier.setComment,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: '평가 제출',
                  icon: Icons.send_outlined,
                  expand: true,
                  loading: formState.isSubmitting,
                  onPressed: formState.isValid ? _submit : null,
                ),
              ],
            ),
    );
  }
}

/// A 1–5 tappable star selector.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i점',
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 40,
              color: i <= rating ? AppColors.warning : AppColors.outlineVariant,
            ),
          ),
      ],
    );
  }
}
