import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/mentoring_model.dart';
import '../mentoring_provider.dart';

/// Course-evaluation results screen for a single class.
///
/// IMPORTANT — anonymity: the backend `EvaluationSummary` payload never carries
/// the submitting student's identity (only aggregates + unattributed comments),
/// and this screen NEVER displays a student id, name or any author handle. Each
/// comment is rendered as an anonymous quote labelled "익명".
///
/// admin_ops / instructor only (server-enforced). Renders inside the
/// authenticated [AppShell].
class ClassEvaluationScreen extends ConsumerWidget {
  const ClassEvaluationScreen({super.key, this.classId});

  static const String routePath = '/instructor/counseling/evaluations';

  /// The class whose evaluation results to show. When null the screen asks the
  /// user to pick a class (deep-linked without an id).
  final int? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = classId;
    if (id == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: EmptyState(
            icon: Icons.fact_check_outlined,
            title: '수업을 선택하세요',
            description: '수업 목록에서 강의 평가 결과를 확인할 수업을 선택하면\n익명 평가 결과가 표시됩니다.',
          ),
        ),
      );
    }

    final state = ref.watch(classEvaluationProvider(id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(classEvaluationProvider(id)),
        child: state.when(
          loading: () => const LoadingView(message: '강의 평가 결과를 불러오는 중입니다.'),
          error: (e, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(classEvaluationProvider(id)),
                ),
              ),
            ],
          ),
          data: (summary) => summary.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.7,
                      child: const Center(
                        child: EmptyState(
                          icon: Icons.rate_review_outlined,
                          title: '아직 제출된 평가가 없습니다',
                          description: '수강생이 강의 평가를 제출하면 익명으로 집계되어 표시됩니다.',
                        ),
                      ),
                    ),
                  ],
                )
              : _EvaluationBody(summary: summary),
        ),
      ),
    );
  }
}

class _EvaluationBody extends StatelessWidget {
  const _EvaluationBody({required this.summary});

  final ClassEvaluation summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _AnonymityBanner(),
        const SizedBox(height: AppSpacing.md),
        _OverviewCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        _DistributionCard(summary: summary),
        if (summary.comments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _CommentsCard(comments: summary.comments),
        ],
      ],
    );
  }
}

/// Reassures the viewer that results are anonymous — reinforcing the privacy
/// contract for everyone reading the page.
class _AnonymityBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '강의 평가는 익명으로 집계됩니다. 작성자 정보는 표시되지 않습니다.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Average rating + submission count.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary});

  final ClassEvaluation summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('평균 평점',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(summary.average.toStringAsFixed(1),
                      style: AppTypography.displayLg),
                  const SizedBox(width: AppSpacing.xs),
                  Text('/ 5.0',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _Stars(value: summary.average),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('참여 인원',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              Text('${summary.count}명', style: AppTypography.headlineMd),
            ],
          ),
        ],
      ),
    );
  }
}

/// Five-star glyph row reflecting [value] (rounded to the nearest half).
class _Stars extends StatelessWidget {
  const _Stars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i
                ? Icons.star_rounded
                : (value >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded),
            size: 20,
            color: AppColors.warning,
          ),
      ],
    );
  }
}

/// Per-star vote distribution with proportional bars.
class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.summary});

  final ClassEvaluation summary;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '평점 분포',
      icon: Icons.bar_chart_rounded,
      child: Column(
        children: [
          for (var star = 5; star >= 1; star--) ...[
            _DistributionRow(
              star: star,
              votes: summary.votesFor(star),
              ratio: summary.ratioFor(star),
            ),
            if (star > 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.star,
    required this.votes,
    required this.ratio,
  });

  final int star;
  final int votes;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text('$star점',
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 36,
          child: Text('$votes',
              textAlign: TextAlign.right, style: AppTypography.bodySm),
        ),
      ],
    );
  }
}

/// Anonymous free-text comments. No author is shown — each is labelled "익명".
class _CommentsCard extends StatelessWidget {
  const _CommentsCard({required this.comments});

  final List<String> comments;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '수강생 의견',
      icon: Icons.forum_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < comments.length; i++) ...[
            _CommentBubble(text: comments[i]),
            if (i < comments.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.outline),
              const SizedBox(width: AppSpacing.xs),
              // Anonymous label only — never an author id/name.
              Text('익명',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(text, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}
