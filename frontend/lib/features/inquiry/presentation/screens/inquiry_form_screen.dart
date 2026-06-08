import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../domain/inquiry_model.dart';
import '../inquiry_provider.dart';

/// Inquiry-create form, mounted at `{basePath}/new` (ops + tech) and also
/// opened from the floating [TechSupportWidget]. On success it pops back (or
/// navigates to the new inquiry detail when [basePath] is provided) and shows a
/// confirmation SnackBar.
class InquiryFormScreen extends ConsumerStatefulWidget {
  const InquiryFormScreen({super.key, this.basePath});

  /// When set, success navigates to `{basePath}/{id}` (the new ticket). When
  /// null (e.g. opened from the global widget) success just pops the form.
  final String? basePath;

  @override
  ConsumerState<InquiryFormScreen> createState() => _InquiryFormScreenState();
}

class _InquiryFormScreenState extends ConsumerState<InquiryFormScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(inquiryFormProvider);
    final notifier = ref.read(inquiryFormProvider.notifier);

    // Navigate away once the inquiry is created.
    ref.listen<InquiryFormState>(inquiryFormProvider, (prev, next) {
      if (next.created != null && (prev?.created == null)) {
        final created = next.created!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('문의가 접수되었습니다.')),
          );
        final base = widget.basePath;
        if (base != null) {
          context.pushReplacement('$base/${created.id}');
        } else if (context.canPop()) {
          context.pop(created);
        }
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: TopBar(
        title: '새 문의 등록',
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppColors.onSurface,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (widget.basePath == '/student/inquiries') ...[
              const _StudentInquiryNotice(),
              const SizedBox(height: AppSpacing.lg),
            ],
            _FieldLabel('유형'),
            DropdownButtonFormField<InquiryType>(
              initialValue: form.type,
              decoration: const InputDecoration(),
              items: [
                for (final t in InquiryType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => v == null ? null : notifier.setType(v),
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldLabel('우선순위'),
            DropdownButtonFormField<InquiryPriority>(
              initialValue: form.priority,
              decoration: const InputDecoration(),
              items: [
                for (final p in InquiryPriority.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) => v == null ? null : notifier.setPriority(v),
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldLabel('제목'),
            TextField(
              controller: _titleCtrl,
              maxLength: 200,
              decoration: const InputDecoration(hintText: '문의 제목을 입력하세요'),
              onChanged: notifier.setTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FieldLabel('내용'),
            TextField(
              controller: _contentCtrl,
              minLines: 6,
              maxLines: 12,
              decoration:
                  const InputDecoration(hintText: '문의 내용을 자세히 작성해주세요'),
              onChanged: notifier.setContent,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '문의 등록',
              icon: Icons.send_rounded,
              expand: true,
              loading: form.isSubmitting,
              onPressed: form.isValid ? notifier.submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only on the student create flow: clarifies that this inquiry goes to
/// the operations/support team (운영·지원팀) as a ticket — not to the assigned
/// instructor (that is «상담»).
class _StudentInquiryNotice extends StatelessWidget {
  const _StudentInquiryNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '운영·지원팀에 전달되는 문의입니다.',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '행정·기술 문제를 티켓으로 접수합니다. '
                  '개인적인 학습·진로 고민은 «상담»을 이용해 주세요.',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
