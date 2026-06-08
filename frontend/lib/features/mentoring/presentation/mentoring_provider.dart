import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mentoring_repository.dart';
import '../domain/mentoring_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Mentoring log list
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the mentoring logs visible to the current user (an instructor only
/// sees their own, server-scoped). Newest session first.
class MentoringLogListNotifier extends AsyncNotifier<List<MentoringLog>> {
  @override
  Future<List<MentoringLog>> build() => _fetch();

  Future<List<MentoringLog>> _fetch() =>
      ref.read(mentoringRepositoryProvider).listMentoringLogs();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final mentoringLogListProvider =
    AsyncNotifierProvider<MentoringLogListNotifier, List<MentoringLog>>(
  MentoringLogListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Cohort students (counseling-subject picker)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the students of [cohortId] (or the whole visible scope when null) for
/// the mentoring-log compose form's subject picker.
final cohortStudentsProvider =
    FutureProvider.family.autoDispose<List<CohortStudent>, int?>(
  (ref, cohortId) =>
      ref.read(mentoringRepositoryProvider).listCohortStudents(
            cohortId: cohortId,
          ),
);

/// ─────────────────────────────────────────────────────────────────────────
/// Compose / submit a mentoring log
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for the mentoring-log compose sheet.
class MentoringFormState {
  const MentoringFormState({
    this.studentId,
    this.sessionDate,
    this.content = '',
    this.followUp = '',
    this.isSubmitting = false,
    this.error,
    this.isSuccess = false,
  });

  final int? studentId;
  final DateTime? sessionDate;
  final String content;
  final String followUp;
  final bool isSubmitting;
  final String? error;

  /// Flips true once the log is created (drives the success feedback).
  final bool isSuccess;

  bool get isValid =>
      studentId != null &&
      sessionDate != null &&
      content.trim().isNotEmpty;

  MentoringFormState copyWith({
    int? studentId,
    DateTime? sessionDate,
    String? content,
    String? followUp,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool? isSuccess,
  }) {
    return MentoringFormState(
      studentId: studentId ?? this.studentId,
      sessionDate: sessionDate ?? this.sessionDate,
      content: content ?? this.content,
      followUp: followUp ?? this.followUp,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Drives the mentoring-log compose form. [cohortId] (optional) is forwarded to
/// the create call so the server stamps the right cohort.
class MentoringFormNotifier extends Notifier<MentoringFormState> {
  MentoringFormNotifier(this.cohortId);

  final int? cohortId;

  @override
  MentoringFormState build() =>
      MentoringFormState(sessionDate: DateTime.now());

  void setStudent(int? id) =>
      state = state.copyWith(studentId: id, clearError: true);
  void setSessionDate(DateTime date) =>
      state = state.copyWith(sessionDate: date, clearError: true);
  void setContent(String v) =>
      state = state.copyWith(content: v, clearError: true);
  void setFollowUp(String v) => state = state.copyWith(followUp: v);

  /// Submits the log. Prevents double submission via [isSubmitting]. On success
  /// flips [isSuccess] and refreshes the list provider so it reflects the new
  /// entry without a manual pull-to-refresh.
  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(mentoringRepositoryProvider).createMentoringLog(
            studentId: state.studentId!,
            sessionDate: state.sessionDate!,
            content: state.content.trim(),
            followUp: state.followUp,
            cohortId: cohortId,
          );
      await ref.read(mentoringLogListProvider.notifier).refresh();
      state = state.copyWith(isSubmitting: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final mentoringFormProvider = NotifierProvider.family<MentoringFormNotifier,
    MentoringFormState, int?>(
  MentoringFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Class evaluation summary (anonymous)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the anonymised evaluation summary for a single class. The payload
/// carries no student identity (see [ClassEvaluation]).
final classEvaluationProvider =
    FutureProvider.family.autoDispose<ClassEvaluation, int>(
  (ref, classId) =>
      ref.read(mentoringRepositoryProvider).getEvaluationSummary(classId),
);
