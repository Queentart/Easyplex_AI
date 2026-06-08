import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inquiry/data/inquiry_repository.dart';
import '../../inquiry/domain/inquiry_model.dart';

/// Providers backing the student 지원·문의 screen.
///
/// Layering note: this file lives in the STUDENT feature but reuses the
/// `inquiry` feature's repository/domain READ-ONLY. The "문의하기" section is the
/// only REAL backend integration (POST /inquiries/) — students hold the
/// `inquiry.create` permission. The helpbot below is a fully MOCK, on-device
/// guided FAQ experience: students are NOT authorized to call the AI agent, so
/// no network request is ever made for it.

/// ─────────────────────────────────────────────────────────────────────────
/// REAL: student inquiry-create form (POST /inquiries/)
/// ─────────────────────────────────────────────────────────────────────────

/// Immutable form state for the student inquiry-create card.
///
/// Kept independent from the ops/tech `inquiryFormProvider` so the student
/// surface owns its own lifecycle (and never leaks ops-only fields like
/// priority into the UI — priority defaults to `normal` server-side).
class StudentInquiryFormState {
  const StudentInquiryFormState({
    this.type = InquiryType.account,
    this.title = '',
    this.content = '',
    this.isSubmitting = false,
    this.error,
    this.created,
  });

  final InquiryType type;
  final String title;
  final String content;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the inquiry is created — drives the success SnackBar + reset.
  final Inquiry? created;

  bool get isValid => title.trim().isNotEmpty && content.trim().isNotEmpty;

  StudentInquiryFormState copyWith({
    InquiryType? type,
    String? title,
    String? content,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Inquiry? created,
    bool clearCreated = false,
  }) {
    return StudentInquiryFormState(
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      created: clearCreated ? null : (created ?? this.created),
    );
  }
}

/// Drives the student inquiry-compose card. Submits via the shared
/// [InquiryRepository] (POST /inquiries/ with a `normal` priority).
class StudentInquiryFormNotifier extends Notifier<StudentInquiryFormState> {
  @override
  StudentInquiryFormState build() => const StudentInquiryFormState();

  void setType(InquiryType v) => state = state.copyWith(type: v);
  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setContent(String v) =>
      state = state.copyWith(content: v, clearError: true);

  /// Clears the one-shot `created` flag after the screen has reacted to it
  /// (so re-entering the screen doesn't re-fire the success SnackBar).
  void acknowledgeCreated() => state = state.copyWith(clearCreated: true);

  /// Submits the inquiry. Guards against double submission via
  /// [StudentInquiryFormState.isSubmitting]. On success sets `created` and
  /// resets the editable fields so the form is ready for the next inquiry.
  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final inquiry = await ref.read(inquiryRepositoryProvider).createInquiry(
            type: state.type.code,
            title: state.title.trim(),
            content: state.content.trim(),
            // Students don't set priority; backend defaults handle it.
            priority: InquiryPriority.normal.code,
          );
      state = StudentInquiryFormState(type: state.type, created: inquiry);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final studentInquiryFormProvider =
    NotifierProvider<StudentInquiryFormNotifier, StudentInquiryFormState>(
  StudentInquiryFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// MOCK: AI 헬프봇 (guided FAQ chat — NO network, NO ai-agent call)
/// ─────────────────────────────────────────────────────────────────────────

/// A single helpbot chat turn. [isUser] right-aligns the bubble.
class HelpBotMessage {
  const HelpBotMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// A canned guided question + its scripted answer.
///
/// MOCK: there is no FAQ/AI backend for students. These are hand-authored
/// responses sourced from the platform rules (출결 / 외출 / 과제) shown in the
/// reference mockups.
class HelpBotPrompt {
  const HelpBotPrompt({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// The guided quick-question chips offered under the helpbot input.
const List<HelpBotPrompt> kHelpBotPrompts = [
  HelpBotPrompt(
    question: '출석 체크는 언제 하나요?',
    // MOCK answer.
    answer: '입실 체크는 수업 시작 전 10분 이내, 퇴실 체크는 세션이 종료된 직후 '
        '메인 화면의 QR 코드 위젯을 통해 완료해 주세요.',
  ),
  HelpBotPrompt(
    question: '외출은 몇 시간까지 가능한가요?',
    // MOCK answer.
    answer: '고용24 및 플랫폼 지침에 따라 일일 최대 2시간까지 외출·조퇴가 가능합니다. '
        '이를 초과하면 결석으로 처리될 수 있으니 주의해 주세요.',
  ),
  HelpBotPrompt(
    question: '결석 인정 서류는 어떻게 제출하나요?',
    // MOCK answer.
    answer: '병결·공결 등 인정 사유가 있으면 "조퇴·병결 신청" 메뉴에서 신청서를 작성하고 '
        '증빙 서류를 첨부해 제출하면 운영팀이 검토 후 승인합니다.',
  ),
  HelpBotPrompt(
    question: '과제 마감일은 어디서 확인하나요?',
    // MOCK answer.
    answer: '"과제" 메뉴에서 각 과제의 마감일(D-day)을 확인할 수 있습니다. '
        '마감이 지나면 제출 버튼이 비활성화되니 미리 제출해 주세요.',
  ),
];

/// Drives the MOCK helpbot conversation. Appends a canned bot answer for the
/// selected prompt — purely local, never touches the network.
class HelpBotNotifier extends Notifier<List<HelpBotMessage>> {
  @override
  List<HelpBotMessage> build() => const [
        HelpBotMessage(
          // MOCK greeting.
          text: '안녕하세요! 출결·외출·과제 관련 자주 묻는 질문에 안내해 드릴게요. '
              '아래 추천 질문을 선택해 보세요.',
          isUser: false,
        ),
      ];

  /// Sends a guided prompt: echoes the user's question, then the canned answer.
  void ask(HelpBotPrompt prompt) {
    state = [
      ...state,
      HelpBotMessage(text: prompt.question, isUser: true),
      HelpBotMessage(text: prompt.answer, isUser: false),
    ];
  }

  /// Sends free-form text. Matches a known prompt when possible, otherwise
  /// returns a fixed fallback steering the student to a 1:1 inquiry.
  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final match = kHelpBotPrompts.where(
      (p) => p.question.contains(trimmed) || trimmed.contains(p.question),
    );
    final answer = match.isNotEmpty
        ? match.first.answer
        // MOCK fallback.
        : '아직 데모 단계라 자유 질문에는 답변이 제한적이에요. 아래 추천 질문을 이용하거나, '
            '정확한 답변이 필요하면 위의 "문의하기"로 1:1 문의를 남겨 주세요.';
    state = [
      ...state,
      HelpBotMessage(text: trimmed, isUser: true),
      HelpBotMessage(text: answer, isUser: false),
    ];
  }
}

final helpBotProvider =
    NotifierProvider<HelpBotNotifier, List<HelpBotMessage>>(
  HelpBotNotifier.new,
);
