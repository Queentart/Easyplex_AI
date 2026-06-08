import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/file_pick.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/utils/file_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../domain/leave_model.dart';
import '../leave_provider.dart';

/// New early-leave / sick-leave (조퇴·병결) request form.
///
/// Fields: type (조퇴/병결/공결), target date, start time (조퇴 only), reason,
/// and an optional supporting document uploaded via `/files/presign`.
/// Submit is disabled until the form is valid and re-disabled while in flight
/// to prevent duplicate submission.
class LeaveRequestFormScreen extends ConsumerStatefulWidget {
  const LeaveRequestFormScreen({super.key, this.prefill});

  static const String routePath = '/student/leave-requests/new';

  /// Optional values to pre-populate the form with (e.g. arriving from the
  /// attendance exceptions list). Decoded from query params in `leave_routes`.
  final LeaveFormPrefill? prefill;

  @override
  ConsumerState<LeaveRequestFormScreen> createState() =>
      _LeaveRequestFormScreenState();
}

class _LeaveRequestFormScreenState
    extends ConsumerState<LeaveRequestFormScreen> {
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start each visit from a clean form, then apply any navigation prefill.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(leaveFormProvider);
      _reasonController.clear();
      final prefill = widget.prefill;
      if (prefill != null && !prefill.isEmpty) {
        ref.read(leaveFormProvider.notifier).seed(prefill);
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _goBackToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student/leave-requests');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: '신청 일자 선택',
    );
    if (picked != null) {
      ref.read(leaveFormProvider.notifier).setTargetDate(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: '조퇴 시각 선택',
    );
    if (picked != null) {
      ref
          .read(leaveFormProvider.notifier)
          .setStartTime(TimeOfDayValue(picked.hour, picked.minute));
    }
  }

  Future<void> _pickEvidence() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickFiles();
      if (picked.isEmpty) return; // user cancelled
      final file = picked.first;
      if (!FileUtils.isWithinSizeLimit(file.size)) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
              '${file.fileName}: 최대 '
              '${FileUtils.humanSize(FileUtils.maxUploadBytes)}까지 첨부할 수 있습니다.',
            ),
          ));
        return;
      }
      await ref.read(leaveFormProvider.notifier).uploadEvidence(
            fileName: file.fileName,
            bytes: file.bytes,
            contentType: file.contentType,
          );
      if (!mounted) return;
      final error = ref.read(leaveFormProvider).error;
      if (error != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('파일을 불러오지 못했습니다.')));
    }
  }

  Future<void> _submit() async {
    final created = await ref.read(leaveFormProvider.notifier).submit();
    if (!mounted) return;
    if (created != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('조퇴·병결 신청이 접수되었습니다.')),
        );
      _goBackToList();
    } else {
      final error = ref.read(leaveFormProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaveFormProvider);
    final notifier = ref.read(leaveFormProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('조퇴·병결 신청'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBackToList,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.isMobile(context)
              ? AppSpacing.md
              : AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _FieldLabel('신청 유형'),
                  const SizedBox(height: AppSpacing.sm),
                  _TypeSelector(
                    selected: state.type,
                    onChanged: notifier.setType,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const _FieldLabel('신청 일자'),
                  const SizedBox(height: AppSpacing.sm),
                  _PickerField(
                    icon: Icons.calendar_today_outlined,
                    value: state.targetDate == null
                        ? null
                        : DateFormatter.date(state.targetDate!),
                    hint: '일자를 선택하세요',
                    onTap: _pickDate,
                  ),

                  if (state.requiresStartTime) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const _FieldLabel('조퇴 시각'),
                    const SizedBox(height: AppSpacing.sm),
                    _PickerField(
                      icon: Icons.schedule_outlined,
                      value: state.startTime?.label,
                      hint: '시각을 선택하세요',
                      onTap: _pickTime,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  const _FieldLabel('사유'),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: notifier.setReason,
                    decoration: const InputDecoration(
                      hintText: '사유를 입력하세요',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  const _FieldLabel('증빙 서류 (선택)'),
                  const SizedBox(height: AppSpacing.sm),
                  _EvidenceField(
                    evidence: state.evidence,
                    isUploading: state.isUploading,
                    onRemove: notifier.removeEvidence,
                    onPick: _pickEvidence,
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: '신청 제출',
                    expand: true,
                    loading: state.isSubmitting,
                    onPressed: state.isValid ? _submit : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.labelMd);
  }
}

/// Segmented type selector (조퇴 / 병결 / 공결).
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final LeaveType selected;
  final ValueChanged<LeaveType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final t in LeaveType.values)
          ChoiceChip(
            label: Text(t.label),
            selected: t == selected,
            onSelected: (_) => onChanged(t),
            selectedColor: AppColors.primaryContainer,
            labelStyle: AppTypography.labelMd.copyWith(
              color: t == selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurfaceVariant,
            ),
            backgroundColor: AppColors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}

/// Tappable read-only field that opens a picker (date / time).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: AppColors.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.outline),
            const SizedBox(width: AppSpacing.sm),
            Text(
              hasValue ? value! : hint,
              style: AppTypography.bodyMd.copyWith(
                color:
                    hasValue ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Supporting-document field.
///
/// When a document has been uploaded it shows the name + size + remove action.
/// The upload pipeline (presign → S3 PUT) is implemented in
/// [LeaveFormNotifier.uploadEvidence]; the attach button opens the platform
/// file picker (via `file_picker`) and feeds it the picked bytes.
class _EvidenceField extends StatelessWidget {
  const _EvidenceField({
    required this.evidence,
    required this.isUploading,
    required this.onRemove,
    required this.onPick,
  });

  final UploadedFile? evidence;
  final bool isUploading;
  final VoidCallback onRemove;

  /// Opens the file picker to choose a supporting document.
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (isUploading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: const [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('업로드 중...'),
          ],
        ),
      );
    }

    if (evidence != null) {
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
          children: [
            const Icon(Icons.description_outlined,
                size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evidence!.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm,
                  ),
                  Text(
                    FileUtils.humanSize(evidence!.fileSize),
                    style: AppTypography.labelSm,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: '첨부 삭제',
              onPressed: onRemove,
            ),
          ],
        ),
      );
    }

    // No file yet — open the platform file picker.
    return AppButton(
      label: '파일 첨부',
      icon: Icons.attach_file_rounded,
      variant: AppButtonVariant.secondary,
      onPressed: onPick,
    );
  }
}
