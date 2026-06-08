import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Training-log compose / edit screen for a class.
///
/// Loads any existing log first: when present the form starts in edit mode and
/// surfaces the 24h edit window (a banner + a disabled state once it closes);
/// when absent it starts in create mode. The window itself is enforced
/// server-side — the UI mirrors it so the instructor isn't surprised by a 422.
class TrainingLogFormScreen extends ConsumerStatefulWidget {
  const TrainingLogFormScreen({super.key, required this.classId});

  final int classId;

  @override
  ConsumerState<TrainingLogFormScreen> createState() =>
      _TrainingLogFormScreenState();
}

class _TrainingLogFormScreenState
    extends ConsumerState<TrainingLogFormScreen> {
  int get _classId => widget.classId;

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(trainingLogProvider(_classId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('훈련일지'),
        backgroundColor: AppColors.surface,
      ),
      body: logState.when(
        loading: () => const LoadingView(message: '훈련일지를 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(trainingLogProvider(_classId)),
        ),
        data: (state) => _Form(classId: _classId, existing: state.log),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.classId, required this.existing});

  final int classId;
  final TrainingLog? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final TextEditingController _content;
  late final TextEditingController _achievements;
  late final TextEditingController _nextPlan;

  bool get _isEdit => widget.existing != null;

  /// Edit is blocked client-side only when the server window has already
  /// closed; create mode (no existing log) is always allowed.
  bool get _locked => _isEdit && !widget.existing!.isEditable;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _content = TextEditingController(text: existing?.content ?? '');
    _achievements = TextEditingController(text: existing?.achievements ?? '');
    _nextPlan = TextEditingController(text: existing?.nextPlan ?? '');
    if (existing != null) {
      // Seed the form notifier so the initial validity reflects the prefilled
      // content (run after the first frame to avoid mutating during build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(trainingLogFormProvider(widget.classId).notifier).seed(existing);
      });
    }
  }

  @override
  void dispose() {
    _content.dispose();
    _achievements.dispose();
    _nextPlan.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier =
        ref.read(trainingLogFormProvider(widget.classId).notifier);
    notifier
      ..setContent(_content.text)
      ..setAchievements(_achievements.text)
      ..setNextPlan(_nextPlan.text);
    await notifier.submit(isEdit: _isEdit);

    if (!mounted) return;
    final state = ref.read(trainingLogFormProvider(widget.classId));
    if (state.saved != null) {
      ref.invalidate(trainingLogProvider(widget.classId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '훈련일지를 수정했습니다.' : '훈련일지를 저장했습니다.')),
      );
      if (context.canPop()) context.pop();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(trainingLogFormProvider(widget.classId));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _editWindowBanner(),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('수업 내용', required: true),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _content,
                enabled: !_locked,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '오늘 진행한 수업 내용을 입력하세요',
                ),
                onChanged: (v) => ref
                    .read(trainingLogFormProvider(widget.classId).notifier)
                    .setContent(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('성취 사항'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _achievements,
                enabled: !_locked,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '학생들의 성취·특이사항 (선택)',
                ),
                onChanged: (v) => ref
                    .read(trainingLogFormProvider(widget.classId).notifier)
                    .setAchievements(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('다음 계획'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nextPlan,
                enabled: !_locked,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '다음 수업 계획 (선택)',
                ),
                onChanged: (v) => ref
                    .read(trainingLogFormProvider(widget.classId).notifier)
                    .setNextPlan(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _isEdit ? '수정 저장' : '훈련일지 저장',
          icon: Icons.save_outlined,
          expand: true,
          loading: formState.isSubmitting,
          onPressed: _locked || !formState.isValid ? null : _submit,
        ),
        if (_locked) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '작성 후 24시간이 지나 수정할 수 없습니다.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text, style: AppTypography.labelMd),
        if (required)
          Text(' *', style: AppTypography.labelMd.copyWith(color: AppColors.error)),
      ],
    );
  }

  /// The 24h edit-window banner. Create mode shows an informational note; edit
  /// mode shows the remaining time (or a closed-window warning).
  Widget _editWindowBanner() {
    if (!_isEdit) {
      return _Banner(
        tone: StatusTone.info,
        icon: Icons.info_outline_rounded,
        title: '수정 가능 시간 안내',
        message: '훈련일지는 저장(제출) 후 24시간 이내에만 수정할 수 있습니다.',
      );
    }

    final log = widget.existing!;
    if (_locked) {
      return _Banner(
        tone: StatusTone.danger,
        icon: Icons.lock_clock_outlined,
        title: '수정 기한 만료',
        message:
            '${DateFormatter.dateTime(log.editDeadline)}까지 수정 가능했습니다. 현재는 열람만 가능합니다.',
      );
    }

    final remaining = log.remainingEditWindow;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return _Banner(
      tone: StatusTone.warning,
      icon: Icons.timelapse_rounded,
      title: '수정 가능 시간 남음',
      message: '약 $hours시간 $minutes분 후(${DateFormatter.dateTime(log.editDeadline)}) '
          '수정이 마감됩니다.',
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
  });

  final StatusTone tone;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(label: title, tone: tone),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
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
