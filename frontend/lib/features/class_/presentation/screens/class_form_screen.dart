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
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/class_model.dart';
import '../class_provider.dart';

/// Create / edit a class session (instructor & admin_ops, matching the
/// `POST /classes` + `PATCH /classes/{id}` RBAC).
///
/// When [classId] is null the screen runs in create mode and seeds the required
/// `cohort_id` / `instructor_id` from the current instructor; otherwise it loads
/// the target class and starts in edit mode. Non-instructor/non-admin viewers
/// are shown an access-denied state (the server also enforces this).
class ClassFormScreen extends ConsumerWidget {
  const ClassFormScreen({super.key, this.classId});

  /// Null = create, otherwise the class being edited.
  final int? classId;

  bool _canManage(String? role) => role == 'instructor' || role == 'admin_ops';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isEdit = classId != null;

    final scaffold = Scaffold(
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
              ? _EditLoader(classId: classId!)
              : const _Form(classId: 0, existing: null),
    );
    return scaffold;
  }
}

/// Loads the target class then renders the form pre-filled (edit mode).
class _EditLoader extends ConsumerWidget {
  const _EditLoader({required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classDetailProvider(classId));
    return state.when(
      loading: () => const LoadingView(message: '수업 정보를 불러오는 중입니다'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(classDetailProvider(classId)),
      ),
      data: (session) => _Form(classId: classId, existing: session),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({
    required this.classId,
    required this.existing,
  });

  final int classId;
  final ClassSession? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final TextEditingController _title;
  late final TextEditingController _location;

  bool get _isEdit => widget.existing != null;

  int get _famId => widget.classId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _location = TextEditingController(text: existing?.location ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(classFormProvider(_famId).notifier);
      if (existing != null) {
        notifier.seed(existing);
      } else {
        final user = ref.read(currentUserProvider);
        notifier.seedForCreate(
          cohortId: user?.cohortId,
          instructorId: user?.id,
        );
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = ref.read(classFormProvider(_famId)).date ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ref.read(classFormProvider(_famId).notifier).setDate(picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final state = ref.read(classFormProvider(_famId));
    final initial = _parseTime(isStart ? state.startTime : state.endTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      final value = '$hh:$mm';
      final notifier = ref.read(classFormProvider(_famId).notifier);
      isStart ? notifier.setStartTime(value) : notifier.setEndTime(value);
    }
  }

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _submit() async {
    final notifier = ref.read(classFormProvider(_famId).notifier);
    notifier
      ..setTitle(_title.text)
      ..setLocation(_location.text);
    await notifier.submit();

    if (!mounted) return;
    final state = ref.read(classFormProvider(_famId));
    if (state.saved != null) {
      ref.invalidate(classListProvider);
      if (_isEdit) ref.invalidate(classDetailProvider(widget.classId));
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
    final formState = ref.watch(classFormProvider(_famId));

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
                    ref.read(classFormProvider(_famId).notifier).setTitle,
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('날짜', required: true),
              const SizedBox(height: AppSpacing.sm),
              _PickerField(
                icon: Icons.calendar_today_rounded,
                value: formState.date == null
                    ? null
                    : DateFormatter.date(formState.date!),
                placeholder: '날짜 선택',
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('시작 시간', required: true),
                        const SizedBox(height: AppSpacing.sm),
                        _PickerField(
                          icon: Icons.schedule_rounded,
                          value: formState.startTime.isEmpty
                              ? null
                              : formState.startTime,
                          placeholder: '시작',
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('종료 시간', required: true),
                        const SizedBox(height: AppSpacing.sm),
                        _PickerField(
                          icon: Icons.schedule_rounded,
                          value: formState.endTime.isEmpty
                              ? null
                              : formState.endTime,
                          placeholder: '종료',
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('장소'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _location,
                decoration:
                    const InputDecoration(hintText: '강의실 / 온라인 링크 (선택)'),
                onChanged:
                    ref.read(classFormProvider(_famId).notifier).setLocation,
              ),
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

/// A tappable field that opens a date / time picker.
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
