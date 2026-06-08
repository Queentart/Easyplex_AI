import '../../../../core/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/chat_bubble.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../inquiry/domain/inquiry_model.dart';
import '../student_support_provider.dart';

/// 수강생 지원·문의 화면.
///
/// Replaces the `/student/support` placeholder. Rendered inside the
/// authenticated app shell, so it returns scrollable page content only
/// (no Scaffold / AppBar of its own — matching [StudentDashboardPage]).
///
/// Three sections:
///   1. 문의하기 (REAL) — creates an inquiry via POST /inquiries/.
///   2. 자주 묻는 질문 (MOCK) — static FAQ accordion (no backend).
///   3. AI 헬프봇 (MOCK) — guided canned-answer chat (students can't call the
///      AI agent, so this is a labeled demo).
class StudentSupportScreen extends ConsumerWidget {
  const StudentSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          _Header(),
          SizedBox(height: AppSpacing.lg),
          // Wide layout: form + helpbot side by side, FAQ full-width below.
          ResponsiveLayout(
            mobile: _SupportColumn.new,
            tablet: _SupportWide.new,
            desktop: _SupportWide.new,
          ),
        ],
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
        Text(AppLabels.support, style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '운영팀에 1:1 문의를 남기거나, 자주 묻는 질문과 헬프봇으로 빠르게 도움을 받아보세요.',
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Mobile: single column, form → FAQ → helpbot.
class _SupportColumn extends StatelessWidget {
  const _SupportColumn(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InquiryFormCard(),
        SizedBox(height: AppSpacing.lg),
        _FaqCard(),
        SizedBox(height: AppSpacing.lg),
        _HelpBotCard(),
      ],
    );
  }
}

/// Tablet / desktop: form + helpbot in a row, FAQ full-width below.
class _SupportWide extends StatelessWidget {
  const _SupportWide(BuildContext context);

  @override
  Widget build(BuildContext context) {
    // NOTE: do NOT wrap this Row in IntrinsicHeight — the helpbot card holds a
    // scrollable (ListView) which has no intrinsic height, so IntrinsicHeight
    // throws a layout error (blank screen on wide viewports). Let the cards size
    // naturally.
    return const Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _InquiryFormCard()),
            SizedBox(width: AppSpacing.lg),
            Expanded(child: _HelpBotCard()),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        _FaqCard(),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Section 1 — 문의하기 (REAL: POST /inquiries/)
/// ─────────────────────────────────────────────────────────────────────────

class _InquiryFormCard extends ConsumerStatefulWidget {
  const _InquiryFormCard();

  @override
  ConsumerState<_InquiryFormCard> createState() => _InquiryFormCardState();
}

class _InquiryFormCardState extends ConsumerState<_InquiryFormCard> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  /// Student-facing inquiry types (priority is fixed to `normal` server-side).
  static const _types = [
    InquiryType.account,
    InquiryType.technical,
    InquiryType.operation,
    InquiryType.etc,
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(studentInquiryFormProvider);
    final notifier = ref.read(studentInquiryFormProvider.notifier);

    // React to create-success / error once each.
    ref.listen<StudentInquiryFormState>(studentInquiryFormProvider,
        (prev, next) {
      if (next.created != null && prev?.created == null) {
        // Reset the local controllers (notifier already cleared its fields).
        _titleCtrl.clear();
        _contentCtrl.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('문의가 접수되었습니다. 운영팀이 확인 후 답변드립니다.'),
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
      title: '문의하기',
      icon: Icons.contact_support_outlined,
      trailing: const StatusChip(label: '운영팀 1:1', tone: StatusTone.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('문의 유형'),
          DropdownButtonFormField<InquiryType>(
            initialValue: form.type,
            decoration: const InputDecoration(),
            items: [
              for (final t in _types)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: form.isSubmitting
                ? null
                : (v) => v == null ? null : notifier.setType(v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('제목'),
          TextField(
            controller: _titleCtrl,
            maxLength: 200,
            enabled: !form.isSubmitting,
            decoration: const InputDecoration(hintText: '문의 제목을 입력하세요'),
            onChanged: notifier.setTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FieldLabel('내용'),
          TextField(
            controller: _contentCtrl,
            minLines: 5,
            maxLines: 10,
            enabled: !form.isSubmitting,
            decoration: const InputDecoration(
              hintText: '문의 내용을 자세히 작성해주세요',
            ),
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
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Section 2 — 자주 묻는 질문 / 도움말 (MOCK)
/// ─────────────────────────────────────────────────────────────────────────

/// MOCK: static FAQ entries. There is no FAQ backend; these are hand-authored.
class _FaqEntry {
  const _FaqEntry(this.question, this.answer);
  final String question;
  final String answer;
}

const List<_FaqEntry> _faqs = [
  _FaqEntry(
    '비밀번호를 잊어버렸어요.',
    '로그인 화면의 "비밀번호 찾기"로 재설정 메일을 받을 수 있습니다. 메일이 오지 않으면 '
        '위의 "문의하기"에서 계정/접속 유형으로 문의해 주세요.',
  ),
  _FaqEntry(
    '출석이 잘못 처리된 것 같아요.',
    '먼저 "출결 현황"에서 기록을 확인한 뒤, 오류가 있다면 운영팀에 1:1 문의를 남겨 주세요. '
        '확인 후 정정 처리됩니다.',
  ),
  _FaqEntry(
    '수업 녹화본은 어디서 보나요?',
    '"수업" 메뉴의 각 수업 상세에서 녹화 링크를 확인할 수 있습니다. 링크가 보이지 않으면 '
        '강사/운영팀에 문의해 주세요.',
  ),
  _FaqEntry(
    '과제를 다시 제출할 수 있나요?',
    '마감 전이라면 "과제" 상세에서 재제출이 가능합니다. 마감 이후에는 제출이 제한됩니다.',
  ),
];

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '자주 묻는 질문 · 도움말',
      icon: Icons.quiz_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MockNotice('아직 FAQ 콘텐츠가 정식 연동되기 전이라 예시 답변으로 표시됩니다.'),
          const SizedBox(height: AppSpacing.sm),
          for (final faq in _faqs)
            Theme(
              // Remove the default ExpansionTile divider lines for a cleaner card.
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                ),
                iconColor: AppColors.primary,
                collapsedIconColor: AppColors.outline,
                title: Text(
                  faq.question,
                  style:
                      AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      faq.answer,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
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
/// Section 3 — AI 헬프봇 (MOCK)
/// ─────────────────────────────────────────────────────────────────────────

class _HelpBotCard extends ConsumerStatefulWidget {
  const _HelpBotCard();

  @override
  ConsumerState<_HelpBotCard> createState() => _HelpBotCardState();
}

class _HelpBotCardState extends ConsumerState<_HelpBotCard> {
  final _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _sendFreeText() {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    ref.read(helpBotProvider.notifier).send(text);
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(helpBotProvider);
    final notifier = ref.read(helpBotProvider.notifier);

    return AppSectionCard(
      title: 'AI 헬프봇',
      icon: Icons.smart_toy_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MockNotice('데모 — 정식 AI 지원 준비 중입니다. 추천 질문에 한해 안내해 드려요.'),
          const SizedBox(height: AppSpacing.md),
          // Chat transcript.
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: AppColors.paleSand,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ListView.separated(
              shrinkWrap: true,
              reverse: true,
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                // reverse:true → render newest at the bottom.
                final msg = messages[messages.length - 1 - i];
                return ChatBubble.text(msg.text, isUser: msg.isUser);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Guided quick-question chips.
          Text(
            '추천 질문',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final prompt in kHelpBotPrompts)
                _PromptChip(
                  label: prompt.question,
                  onTap: () => notifier.ask(prompt),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Free-text input (mock matcher / fallback).
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(
                    hintText: '궁금한 점을 입력해보세요',
                  ),
                  onSubmitted: (_) => _sendFreeText(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                icon: const Icon(Icons.send_rounded),
                onPressed: _sendFreeText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTypography.labelMd.copyWith(color: AppColors.primary),
          ),
        ),
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

/// A small inline banner marking a MOCK / demo region for the user.
class _MockNotice extends StatelessWidget {
  const _MockNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.onWarningContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onWarningContainer),
            ),
          ),
        ],
      ),
    );
  }
}
