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
import '../class_provider.dart';

/// Create a career posting (job / certification / special lecture).
///
/// admin_ops only — this mirrors the `POST /career-postings` RBAC. Other roles
/// are shown an access-denied state (the server also returns 403). On success
/// the postings list is invalidated so the new entry appears immediately.
class CareerFormScreen extends ConsumerWidget {
  const CareerFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('공지 등록'),
        backgroundColor: AppColors.surface,
      ),
      body: user?.role != 'admin_ops'
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: '접근 권한이 없습니다',
              description: '취업·자격 공지 등록은 운영팀만 가능합니다.',
            )
          : const _CareerForm(),
    );
  }
}

class _CareerForm extends ConsumerStatefulWidget {
  const _CareerForm();

  @override
  ConsumerState<_CareerForm> createState() => _CareerFormState();
}

class _CareerFormState extends ConsumerState<_CareerForm> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _url;

  static const _types = <({String value, String label})>[
    (value: 'job', label: '채용'),
    (value: 'certification', label: '자격증'),
    (value: 'special_lecture', label: '특강'),
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _content = TextEditingController();
    _url = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final state = ref.read(careerFormProvider);
    final current = (isStart ? state.startDate : state.endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final notifier = ref.read(careerFormProvider.notifier);
      isStart ? notifier.setStartDate(picked) : notifier.setEndDate(picked);
    }
  }

  Future<void> _submit() async {
    final notifier = ref.read(careerFormProvider.notifier);
    notifier
      ..setTitle(_title.text)
      ..setContent(_content.text)
      ..setExternalUrl(_url.text);
    await notifier.submit();

    if (!mounted) return;
    final state = ref.read(careerFormProvider);
    if (state.saved != null) {
      ref.invalidate(careerPostingListProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('공지를 등록했습니다.')));
      if (context.canPop()) context.pop();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(careerFormProvider);
    final notifier = ref.read(careerFormProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('공지 유형', required: true),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final t in _types)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: formState.postingType == t.value,
                      onSelected: (_) => notifier.setType(t.value),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('제목', required: true),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _title,
                decoration: const InputDecoration(hintText: '공지 제목을 입력하세요'),
                onChanged: notifier.setTitle,
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('내용', required: true),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _content,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(hintText: '공지 내용을 입력하세요'),
                onChanged: notifier.setContent,
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('외부 링크'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration:
                    const InputDecoration(hintText: 'https:// (선택)'),
                onChanged: notifier.setExternalUrl,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('시작일'),
                        const SizedBox(height: AppSpacing.sm),
                        _DateField(
                          value: formState.startDate == null
                              ? null
                              : DateFormatter.date(formState.startDate!),
                          placeholder: '시작일 (선택)',
                          onTap: () => _pickDate(isStart: true),
                          onClear: formState.startDate == null
                              ? null
                              : () => notifier.setStartDate(null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('마감일'),
                        const SizedBox(height: AppSpacing.sm),
                        _DateField(
                          value: formState.endDate == null
                              ? null
                              : DateFormatter.date(formState.endDate!),
                          placeholder: '마감일 (선택)',
                          onTap: () => _pickDate(isStart: false),
                          onClear: formState.endDate == null
                              ? null
                              : () => notifier.setEndDate(null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '공지 등록',
          icon: Icons.campaign_outlined,
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

/// A tappable date field with an optional clear action.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

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
            Icon(Icons.event_outlined, size: 16, color: AppColors.outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hasValue ? value! : placeholder,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd.copyWith(
                  color: hasValue
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (hasValue && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.outline),
              ),
          ],
        ),
      ),
    );
  }
}
