/// Presentation-layer state for the INSTRUCTOR assignment-grading flow.
///
/// Follows the Riverpod 3.x non-codegen family pattern used by
/// `board_provider.dart`: a plain `Notifier`/`AsyncNotifier` subclass takes its
/// family argument via the constructor (captured in a field), exposes a no-arg
/// `build()`, and is wired with `…Provider.family(N.new)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/grading_repository.dart';
import '../domain/assignment_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Assignment picker (instructor-scoped list)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the assignments the instructor can grade (backend scopes to their
/// cohort / authored assignments). Drives the assignment picker.
class GradingAssignmentsNotifier extends AsyncNotifier<List<Assignment>> {
  @override
  Future<List<Assignment>> build() => _fetch();

  Future<List<Assignment>> _fetch() =>
      ref.read(gradingRepositoryProvider).listAssignments();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final gradingAssignmentsProvider =
    AsyncNotifierProvider<GradingAssignmentsNotifier, List<Assignment>>(
  GradingAssignmentsNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Submissions for one assignment
/// ─────────────────────────────────────────────────────────────────────────

/// Loads + maintains the submission rows for a single assignment. Family
/// argument ([assignmentId]) is captured by the factory — non-codegen 3.x
/// notifiers don't receive it in [build].
class SubmissionRowsNotifier extends AsyncNotifier<List<SubmissionRow>> {
  SubmissionRowsNotifier(this.assignmentId);

  final int assignmentId;

  @override
  Future<List<SubmissionRow>> build() => _fetch();

  Future<List<SubmissionRow>> _fetch() =>
      ref.read(gradingRepositoryProvider).listSubmissions(assignmentId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Reflects a freshly graded [submission] in the list without a round-trip
  /// (optimistic): updates the matching row's score + status in place.
  void applyGraded(Submission submission) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final row in current)
        if (row.id == submission.id)
          SubmissionRow(
            id: row.id,
            studentId: row.studentId,
            studentName: row.studentName,
            submittedAt: row.submittedAt,
            isLate: row.isLate,
            score: submission.score,
            status: submission.status,
          )
        else
          row,
    ]);
  }
}

final submissionRowsProvider = AsyncNotifierProvider.family<
    SubmissionRowsNotifier, List<SubmissionRow>, int>(
  SubmissionRowsNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Single submission detail (read content before grading)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the full [Submission] (incl. `content`) for the grading editor.
final submissionDetailProvider =
    FutureProvider.family.autoDispose<Submission, int>((ref, submissionId) {
  return ref.read(gradingRepositoryProvider).getSubmission(submissionId);
});

/// ─────────────────────────────────────────────────────────────────────────
/// Feedback / score editor form
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for the feedback editor of one submission.
class FeedbackFormState {
  const FeedbackFormState({
    this.scoreText = '',
    this.feedback = '',
    this.requestResubmit = false,
    this.isSubmitting = false,
    this.error,
    this.saved,
  });

  /// Raw score text from the field (validated lazily so the user can clear it).
  final String scoreText;
  final String feedback;

  /// When true the submission is sent back with `resubmit_requested` status.
  final bool requestResubmit;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the feedback is saved (drives the success SnackBar + close).
  final Submission? saved;

  int? get score {
    final t = scoreText.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  /// Feedback text is mandatory (backend `FeedbackRequest.feedback`). When a
  /// score is typed it must parse to a non-negative int.
  bool get isValid {
    if (feedback.trim().isEmpty) return false;
    final t = scoreText.trim();
    if (t.isNotEmpty) {
      final parsed = int.tryParse(t);
      if (parsed == null || parsed < 0) return false;
    }
    return true;
  }

  FeedbackFormState copyWith({
    String? scoreText,
    String? feedback,
    bool? requestResubmit,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Submission? saved,
  }) {
    return FeedbackFormState(
      scoreText: scoreText ?? this.scoreText,
      feedback: feedback ?? this.feedback,
      requestResubmit: requestResubmit ?? this.requestResubmit,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

/// Drives the feedback/score editor for one submission (captured in
/// [submissionId]). Prevents duplicate submission via [isSubmitting].
class FeedbackFormNotifier extends Notifier<FeedbackFormState> {
  FeedbackFormNotifier(this.submissionId);

  final int submissionId;

  @override
  FeedbackFormState build() => const FeedbackFormState();

  /// Seeds the form from an already-loaded submission (existing score).
  void seed({int? score}) {
    state = state.copyWith(
      scoreText: score?.toString() ?? '',
    );
  }

  void setScore(String v) =>
      state = state.copyWith(scoreText: v, clearError: true);
  void setFeedback(String v) =>
      state = state.copyWith(feedback: v, clearError: true);
  void setRequestResubmit(bool v) =>
      state = state.copyWith(requestResubmit: v);

  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final updated = await ref.read(gradingRepositoryProvider).giveFeedback(
            submissionId,
            feedback: state.feedback.trim(),
            score: state.score,
            status: state.requestResubmit ? 'resubmit_requested' : 'reviewed',
          );
      state = state.copyWith(isSubmitting: false, saved: updated);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final feedbackFormProvider =
    NotifierProvider.family<FeedbackFormNotifier, FeedbackFormState, int>(
  FeedbackFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Assignment-create form
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for the (optional) assignment-create dialog/form.
class AssignmentCreateState {
  const AssignmentCreateState({
    this.title = '',
    this.description = '',
    this.dueDate,
    this.allowLateSubmission = false,
    this.maxScoreText = '',
    this.isSubmitting = false,
    this.error,
    this.created,
  });

  final String title;
  final String description;
  final DateTime? dueDate;
  final bool allowLateSubmission;
  final String maxScoreText;
  final bool isSubmitting;
  final String? error;

  /// Non-null once created (drives navigation/refresh).
  final Assignment? created;

  int? get maxScore {
    final t = maxScoreText.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  bool get isValid =>
      title.trim().isNotEmpty &&
      description.trim().isNotEmpty &&
      dueDate != null;

  AssignmentCreateState copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool? allowLateSubmission,
    String? maxScoreText,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Assignment? created,
  }) {
    return AssignmentCreateState(
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      allowLateSubmission: allowLateSubmission ?? this.allowLateSubmission,
      maxScoreText: maxScoreText ?? this.maxScoreText,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      created: created ?? this.created,
    );
  }
}

/// Drives the assignment-create form for a given cohort (captured in
/// [cohortId]).
class AssignmentCreateNotifier extends Notifier<AssignmentCreateState> {
  AssignmentCreateNotifier(this.cohortId);

  final int cohortId;

  @override
  AssignmentCreateState build() => const AssignmentCreateState();

  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setDescription(String v) =>
      state = state.copyWith(description: v, clearError: true);
  void setDueDate(DateTime v) => state = state.copyWith(dueDate: v);
  void setAllowLate(bool v) =>
      state = state.copyWith(allowLateSubmission: v);
  void setMaxScore(String v) =>
      state = state.copyWith(maxScoreText: v, clearError: true);

  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final created = await ref.read(gradingRepositoryProvider).createAssignment(
            cohortId: cohortId,
            title: state.title.trim(),
            description: state.description.trim(),
            dueDate: state.dueDate!,
            allowLateSubmission: state.allowLateSubmission,
            maxScore: state.maxScore,
          );
      state = state.copyWith(isSubmitting: false, created: created);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final assignmentCreateProvider = NotifierProvider.family<
    AssignmentCreateNotifier, AssignmentCreateState, int>(
  AssignmentCreateNotifier.new,
);
