import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inquiry/data/inquiry_repository.dart';
import '../../inquiry/domain/inquiry_model.dart';

/// Provider backing the student-initiated 상담 신청 (counseling request) form.
///
/// Layering note: this file lives in the STUDENT feature but reuses the
/// `inquiry` feature's repository/domain READ-ONLY.
///
/// Why an INQUIRY (not a mentoring log)?
///   - `POST /mentoring-logs` is instructor-only — students CANNOT author
///     mentoring/counseling records (server-enforced).
///   - There is NO dedicated "counseling request" entity on the backend.
///   - Students DO hold `inquiry.create`, and `POST /inquiries/` accepts a
///     free-form `type`. So a student-initiated counseling REQUEST is modelled
///     as an inquiry routed to staff/instructor.
///
/// Counseling type code: we send [InquiryType.operation] (`operation` →
/// "운영 문의"), the closest existing inquiry type for a 상담 request that goes to
/// the operations team / instructor. The free-form backend `type` accepts it,
/// and ops/instructor inbox tooling already filters on this type.

/// Immutable form state for the student counseling-request card.
class CounselingRequestState {
  const CounselingRequestState({
    this.topic = '',
    this.detail = '',
    this.isSubmitting = false,
    this.error,
    this.created,
  });

  /// 상담 주제 → maps to the inquiry `title`.
  final String topic;

  /// 상담 내용 → maps to the inquiry `content`.
  final String detail;

  final bool isSubmitting;
  final String? error;

  /// Non-null once the request is created — drives the success feedback + reset.
  final Inquiry? created;

  bool get isValid => topic.trim().isNotEmpty && detail.trim().isNotEmpty;

  CounselingRequestState copyWith({
    String? topic,
    String? detail,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Inquiry? created,
    bool clearCreated = false,
  }) {
    return CounselingRequestState(
      topic: topic ?? this.topic,
      detail: detail ?? this.detail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      created: clearCreated ? null : (created ?? this.created),
    );
  }
}

/// Drives the student counseling-request form. Submits via the shared
/// [InquiryRepository] (`POST /inquiries/`) with the counseling-appropriate
/// `operation` type and the server-default `normal` priority.
class CounselingRequestNotifier extends Notifier<CounselingRequestState> {
  /// The inquiry `type` used for student-initiated counseling requests.
  static const InquiryType counselingType = InquiryType.operation;

  @override
  CounselingRequestState build() => const CounselingRequestState();

  void setTopic(String v) => state = state.copyWith(topic: v, clearError: true);
  void setDetail(String v) =>
      state = state.copyWith(detail: v, clearError: true);

  /// Clears the one-shot `created` flag after the screen has reacted to it (so
  /// re-entering / rebuilding doesn't re-fire the success feedback).
  void acknowledgeCreated() => state = state.copyWith(clearCreated: true);

  /// Submits the counseling request. Guards against double submission via
  /// [CounselingRequestState.isSubmitting]. On success sets `created` and resets
  /// the editable fields so the form is ready for a follow-up request.
  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final inquiry = await ref.read(inquiryRepositoryProvider).createInquiry(
            type: counselingType.code,
            title: state.topic.trim(),
            content: state.detail.trim(),
            // Students don't set priority; backend default (normal) applies.
            priority: InquiryPriority.normal.code,
          );
      state = CounselingRequestState(created: inquiry);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final counselingRequestProvider =
    NotifierProvider<CounselingRequestNotifier, CounselingRequestState>(
  CounselingRequestNotifier.new,
);
