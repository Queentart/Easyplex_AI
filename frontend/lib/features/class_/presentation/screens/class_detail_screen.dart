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
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/class_model.dart';
import '../class_provider.dart';
import 'class_list_screen.dart' show classStatusChip;

/// Class detail: schedule, status, materials, the recording watch link, and an
/// entry point to the training log. Recording / log actions are only offered to
/// the assigned instructor (and admin_ops), matching server-side RBAC.
class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classDetailProvider(classId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('수업 상세'),
        backgroundColor: AppColors.surface,
      ),
      body: state.when(
        loading: () => const LoadingView(message: '수업 정보를 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(classDetailProvider(classId)),
        ),
        data: (session) => _DetailBody(session: session, viewerId: user?.id),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.session, required this.viewerId});

  final ClassSession session;
  final int? viewerId;

  @override
  Widget build(BuildContext context) {
    final chip = classStatusChip(session.status);
    final canManage = session.isOwnedBy(viewerId);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(session.title, style: AppTypography.headlineMd),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(label: chip.label, tone: chip.tone),
                  if (canManage) ...[
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: '수업 수정',
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.outline,
                      onPressed: () => context.push(
                        '/instructor/classes/${session.id}/edit',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                label: '날짜',
                value: DateFormatter.date(session.date),
              ),
              if (session.timeRange.isNotEmpty)
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: '시간',
                  value: session.timeRange,
                ),
              if (session.location != null && session.location!.isNotEmpty)
                _InfoRow(
                  icon: Icons.place_outlined,
                  label: '장소',
                  value: session.location!,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Materials
        AppSectionCard(
          title: '수업 자료',
          icon: Icons.folder_open_outlined,
          child: session.materials.isEmpty
              ? Text(
                  '등록된 자료가 없습니다.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final m in session.materials)
                      StatusChip(
                        label: m.label,
                        tone: StatusTone.neutral,
                        icon: Icons.description_outlined,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Recording link
        AppSectionCard(
          title: '녹화본',
          icon: Icons.videocam_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '수업 종료 후 등록된 녹화본을 시청할 수 있습니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: '녹화본 보기',
                icon: Icons.play_circle_outline_rounded,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => _showRecordingNotice(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Training log entry point
        AppSectionCard(
          title: '훈련일지',
          icon: Icons.menu_book_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '훈련일지는 작성 후 24시간 이내에만 수정할 수 있습니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              if (canManage)
                AppButton(
                  label: '훈련일지 작성·수정',
                  icon: Icons.edit_note_rounded,
                  expand: true,
                  onPressed: () => context.push(
                    '/instructor/classes/${session.id}/training-log',
                  ),
                )
              else
                Text(
                  '담당 강사만 훈련일지를 작성할 수 있습니다.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.outline),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRecordingNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('녹화본 플레이어는 준비 중입니다.')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.outline),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: AppTypography.bodyMd),
          ),
        ],
      ),
    );
  }
}
