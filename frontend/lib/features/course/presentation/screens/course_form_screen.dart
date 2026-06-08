import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cohort_filter.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/course_model.dart';
import '../course_provider.dart';

/// Create / edit a course (instructor & admin_ops, matching the
/// `POST /courses/` + `PATCH /courses/{id}` RBAC).
///
/// When [courseId] is null the screen runs in create mode (cohort chosen from
/// the instructor's taught cohorts); otherwise it loads the target course and
/// starts in edit mode (which also exposes the active/archived status toggle).
class CourseFormScreen extends ConsumerWidget {
  const CourseFormScreen({super.key, this.courseId});

  /// Null = create, otherwise the course being edited.
  final int? courseId;

  bool _canManage(String? role) => role == 'instructor' || role == 'admin_ops';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isEdit = courseId != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isEdit ? '수업 수정' : '수업 생성'),
        backgroundColor: AppColors.surface,
      ),
      body: !_canManage(user?.role)
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: '접근 권한이 없습니다',
              description: '수업 생성·수정은 담당 강사 또는 운영팀만 가능합니다.',
            )
          : isEdit
              ? _EditLoader(courseId: courseId!)
              : const _Form(courseId: 0, existing: null),
    );
  }
}

/// Loads the target course then renders the form pre-filled (edit mode).
class _EditLoader extends ConsumerWidget {
  const _EditLoader({required this.courseId});

  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseDetailProvider(courseId));
    return state.when(
      loading: () => const LoadingView(message: '수업 정보를 불러오는 중입니다'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
      ),
      data: (course) => _Form(courseId: courseId, existing: course),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.courseId, required this.existing});

  final int courseId;
  final Course? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final TextEditingController _title;
  late final TextEditingController _description;

  bool get _isEdit => widget.existing != null;
  int get _famId => widget.courseId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(courseFormProvider(_famId).notifier);
      if (existing != null) {
        notifier.seed(existing);
      } else {
        // Default cohort to the instructor's first taught cohort, if any.
        final user = ref.read(currentUserProvider);
        final firstCohort =
            user?.cohortIds.isNotEmpty == true ? user!.cohortIds.first : null;
        notifier.seedCohort(firstCohort);
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final state = ref.read(courseFormProvider(_famId));
    final picked = await showDatePicker(
      context: context,
      initialDate: state.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ref.read(courseFormProvider(_famId).notifier).setStartDate(picked);
    }
  }

  Future<void> _pickEndDate() async {
    final state = ref.read(courseFormProvider(_famId));
    final picked = await showDatePicker(
      context: context,
      initialDate: state.endDate ?? state.startDate ?? DateTime.now(),
      firstDate: state.startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ref.read(courseFormProvider(_famId).notifier).setEndDate(picked);
    }
  }

  Future<void> _submit() async {
    final notifier = ref.read(courseFormProvider(_famId).notifier);
    notifier
      ..setTitle(_title.text)
      ..setDescription(_description.text);
    await notifier.submit();

    if (!mounted) return;
    final state = ref.read(courseFormProvider(_famId));
    if (state.saved != null) {
      ref.invalidate(courseListProvider);
      if (_isEdit) ref.invalidate(courseDetailProvider(widget.courseId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '수업을 수정했습니다.' : '수업을 생성했습니다.')),
      );
      if (context.canPop()) context.pop();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(courseFormProvider(_famId));
    final cohortOptions = ref.watch(cohortOptionsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('수업명', required: true),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _title,
                decoration: const InputDecoration(hintText: '수업명을 입력하세요'),
                onChanged:
                    ref.read(courseFormProvider(_famId).notifier).setTitle,
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('설명'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration:
                    const InputDecoration(hintText: '수업 설명 (선택)'),
                onChanged: ref
                    .read(courseFormProvider(_famId).notifier)
                    .setDescription,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('시작일', required: true),
                        const SizedBox(height: AppSpacing.sm),
                        _PickerField(
                          icon: Icons.calendar_today_rounded,
                          value: formState.startDate == null
                              ? null
                              : DateFormatter.date(formState.startDate!),
                          placeholder: '시작일 선택',
                          onTap: _pickStartDate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('종료일', required: true),
                        const SizedBox(height: AppSpacing.sm),
                        _PickerField(
                          icon: Icons.event_rounded,
                          value: formState.endDate == null
                              ? null
                              : DateFormatter.date(formState.endDate!),
                          placeholder: '종료일 선택',
                          onTap: _pickEndDate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (formState.startDate != null &&
                  formState.endDate != null &&
                  !formState.datesValid) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '종료일은 시작일과 같거나 이후여야 합니다.',
                  style:
                      AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _label('기수', required: true),
              const SizedBox(height: AppSpacing.sm),
              cohortOptions.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, _) => Text(
                  '기수 목록을 불러오지 못했습니다',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.error),
                ),
                data: (options) => DropdownButtonFormField<int?>(
                  initialValue: formState.cohortId,
                  isExpanded: true,
                  decoration: _dropdownDecoration,
                  hint: const Text('기수 선택'),
                  items: [
                    for (final o in options)
                      DropdownMenuItem<int?>(
                          value: o.id, child: Text(o.name)),
                  ],
                  onChanged: _isEdit
                      ? null // cohort is fixed once a course is created
                      : (v) => ref
                          .read(courseFormProvider(_famId).notifier)
                          .setCohortId(v),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.lg),
                _label('상태'),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<CourseStatus>(
                  initialValue: formState.status == CourseStatus.unknown
                      ? CourseStatus.active
                      : formState.status,
                  isExpanded: true,
                  decoration: _dropdownDecoration,
                  items: const [
                    DropdownMenuItem(
                        value: CourseStatus.active, child: Text('진행 중')),
                    DropdownMenuItem(
                        value: CourseStatus.archived, child: Text('보관됨')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(courseFormProvider(_famId).notifier)
                          .setStatus(v);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _isEdit ? '수정 저장' : '수업 생성',
          icon: Icons.save_outlined,
          expand: true,
          loading: formState.isSubmitting,
          onPressed: formState.isValid ? _submit : null,
        ),
      ],
    );
  }

  InputDecoration get _dropdownDecoration => InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
      );

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text, style: AppTypography.labelMd),
        if (required)
          Text(' *',
              style: AppTypography.labelMd.copyWith(color: AppColors.error)),
      ],
    );
  }
}

/// A tappable field that opens a date picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hasValue ? value! : placeholder,
                style: AppTypography.bodyMd.copyWith(
                  color: hasValue
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
