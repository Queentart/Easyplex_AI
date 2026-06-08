import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/class_repository.dart';
import '../domain/class_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Class list
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the class sessions visible to the current user (server-scoped by
/// cohort / instructor). Newest first.
class ClassListNotifier extends AsyncNotifier<List<ClassSession>> {
  @override
  Future<List<ClassSession>> build() => _fetch();

  Future<List<ClassSession>> _fetch() async {
    final page = await ref.read(classRepositoryProvider).listClasses();
    return page.classes;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final classListProvider =
    AsyncNotifierProvider<ClassListNotifier, List<ClassSession>>(
  ClassListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Single class detail
/// ─────────────────────────────────────────────────────────────────────────

/// Loads a single class by id.
final classDetailProvider =
    FutureProvider.family.autoDispose<ClassSession, int>((ref, classId) async {
  return ref.read(classRepositoryProvider).getClass(classId);
});

/// ─────────────────────────────────────────────────────────────────────────
/// Training log (per class)
/// ─────────────────────────────────────────────────────────────────────────

/// The training-log fetch result: either the existing [log] or `null` when
/// none has been written yet (so the form screen can switch into create mode).
class TrainingLogState {
  const TrainingLogState({this.log});

  final TrainingLog? log;

  bool get exists => log != null;
}

/// Loads the training log for a class. A `NOT_FOUND` from the backend is mapped
/// to an empty [TrainingLogState] (create mode) rather than an error, so the
/// instructor can author a new log.
///
/// Family argument is captured in [classId] by the provider factory — Riverpod
/// 3.x non-codegen notifiers don't receive the argument in [build].
class TrainingLogNotifier extends AsyncNotifier<TrainingLogState> {
  TrainingLogNotifier(this.classId);

  final int classId;

  @override
  Future<TrainingLogState> build() => _fetch();

  Future<TrainingLogState> _fetch() async {
    try {
      final log = await ref.read(classRepositoryProvider).getTrainingLog(classId);
      return TrainingLogState(log: log);
    } on ClassException catch (e) {
      // "Not written yet" is a valid empty state, not a failure.
      if (e.code == 'NOT_FOUND') return const TrainingLogState();
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final trainingLogProvider = AsyncNotifierProvider.family<TrainingLogNotifier,
    TrainingLogState, int>(
  TrainingLogNotifier.new,
);

/// Form state for composing / editing a training log.
class TrainingLogFormState {
  const TrainingLogFormState({
    this.content = '',
    this.achievements = '',
    this.nextPlan = '',
    this.isSubmitting = false,
    this.error,
    this.saved,
  });

  final String content;
  final String achievements;
  final String nextPlan;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the log is created / updated (drives navigation away).
  final TrainingLog? saved;

  bool get isValid => content.trim().isNotEmpty;

  TrainingLogFormState copyWith({
    String? content,
    String? achievements,
    String? nextPlan,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    TrainingLog? saved,
  }) {
    return TrainingLogFormState(
      content: content ?? this.content,
      achievements: achievements ?? this.achievements,
      nextPlan: nextPlan ?? this.nextPlan,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

/// Drives the training-log form for a class (captured in [classId]).
///
/// Seed the form with an existing log via [seed]; [submit] creates when no log
/// exists yet and patches otherwise. Double submission is blocked through
/// [TrainingLogFormState.isSubmitting]. The 24h edit window is enforced
/// server-side: an `EDIT_WINDOW_CLOSED` (422) is surfaced via
/// [TrainingLogFormState.error].
class TrainingLogFormNotifier extends Notifier<TrainingLogFormState> {
  TrainingLogFormNotifier(this.classId);

  final int classId;

  @override
  TrainingLogFormState build() => const TrainingLogFormState();

  /// Pre-fills the form from an existing log (edit mode).
  void seed(TrainingLog log) {
    state = TrainingLogFormState(
      content: log.content,
      achievements: log.achievements ?? '',
      nextPlan: log.nextPlan ?? '',
    );
  }

  void setContent(String v) =>
      state = state.copyWith(content: v, clearError: true);
  void setAchievements(String v) =>
      state = state.copyWith(achievements: v, clearError: true);
  void setNextPlan(String v) =>
      state = state.copyWith(nextPlan: v, clearError: true);

  /// Creates (when [isEdit] is false) or updates the training log.
  Future<void> submit({required bool isEdit}) async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final repo = ref.read(classRepositoryProvider);
    final achievements =
        state.achievements.trim().isEmpty ? null : state.achievements.trim();
    final nextPlan = state.nextPlan.trim().isEmpty ? null : state.nextPlan.trim();
    try {
      final log = isEdit
          ? await repo.updateTrainingLog(
              classId,
              content: state.content.trim(),
              achievements: achievements,
              nextPlan: nextPlan,
            )
          : await repo.createTrainingLog(
              classId,
              content: state.content.trim(),
              achievements: achievements,
              nextPlan: nextPlan,
            );
      state = state.copyWith(isSubmitting: false, saved: log);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final trainingLogFormProvider = NotifierProvider.family<TrainingLogFormNotifier,
    TrainingLogFormState, int>(
  TrainingLogFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Curriculum (per cohort)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads + mutates the curriculum tree for a cohort, with an optimistic
/// completion toggle.
///
/// Family argument is captured in [cohortId] by the provider factory.
class CurriculumNotifier extends AsyncNotifier<List<CurriculumItem>> {
  CurriculumNotifier(this.cohortId);

  final int cohortId;

  @override
  Future<List<CurriculumItem>> build() => _fetch();

  Future<List<CurriculumItem>> _fetch() =>
      ref.read(classRepositoryProvider).listCurriculum(cohortId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Optimistically toggles an item's completion, rolling back on failure so
  /// the checkbox never lies about server state.
  Future<void> toggleCompleted(int itemId, bool isCompleted) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData([
        for (final item in previous)
          item.id == itemId
              ? CurriculumItem(
                  id: item.id,
                  cohortId: item.cohortId,
                  week: item.week,
                  day: item.day,
                  topic: item.topic,
                  description: item.description,
                  plannedHours: item.plannedHours,
                  actualHours: item.actualHours,
                  isCompleted: isCompleted,
                  completedAt: item.completedAt,
                  parentItemId: item.parentItemId,
                  sortOrder: item.sortOrder,
                  createdAt: item.createdAt,
                )
              : item,
      ]);
    }
    try {
      await ref
          .read(classRepositoryProvider)
          .updateCurriculumItem(itemId, isCompleted: isCompleted);
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final curriculumProvider = AsyncNotifierProvider.family<CurriculumNotifier,
    List<CurriculumItem>, int>(
  CurriculumNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Career postings
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the institution's career postings (newest first).
class CareerPostingListNotifier extends AsyncNotifier<List<CareerPosting>> {
  @override
  Future<List<CareerPosting>> build() => _fetch();

  Future<List<CareerPosting>> _fetch() async {
    final page = await ref.read(classRepositoryProvider).listCareerPostings();
    return page.postings;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final careerPostingListProvider =
    AsyncNotifierProvider<CareerPostingListNotifier, List<CareerPosting>>(
  CareerPostingListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Class create / edit form
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for creating or editing a class session.
///
/// [date] / [startTime] / [endTime] map to the backend `date` / `start_time` /
/// `end_time` fields; times are kept as `HH:MM` strings (the repository sends
/// them verbatim). On create, [cohortId] / [instructorId] are required by the
/// schema and seeded from the current instructor.
class ClassFormState {
  const ClassFormState({
    this.title = '',
    this.date,
    this.startTime = '',
    this.endTime = '',
    this.location = '',
    this.cohortId,
    this.instructorId,
    this.isSubmitting = false,
    this.error,
    this.saved,
  });

  final String title;
  final DateTime? date;
  final String startTime;
  final String endTime;
  final String location;
  final int? cohortId;
  final int? instructorId;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the class is created / updated (drives navigation away).
  final ClassSession? saved;

  bool get isValid =>
      title.trim().isNotEmpty &&
      date != null &&
      startTime.isNotEmpty &&
      endTime.isNotEmpty;

  ClassFormState copyWith({
    String? title,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? location,
    int? cohortId,
    int? instructorId,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    ClassSession? saved,
  }) {
    return ClassFormState(
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      cohortId: cohortId ?? this.cohortId,
      instructorId: instructorId ?? this.instructorId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

/// Drives the class create / edit form. The family argument [classId] is `0`
/// for create mode and the target class id for edit mode.
///
/// Double submission is blocked through [ClassFormState.isSubmitting]; on
/// success [ClassFormState.saved] holds the persisted session so the screen can
/// navigate back and the caller can invalidate the list.
class ClassFormNotifier extends Notifier<ClassFormState> {
  ClassFormNotifier(this.classId);

  /// 0 = create, otherwise the class being edited.
  final int classId;

  bool get isEdit => classId > 0;

  @override
  ClassFormState build() => const ClassFormState();

  /// Pre-fills the form from an existing session (edit mode).
  void seed(ClassSession session) {
    state = ClassFormState(
      title: session.title,
      date: session.date,
      startTime: session.startTime,
      endTime: session.endTime,
      location: session.location ?? '',
      cohortId: session.cohortId,
      instructorId: session.instructorId,
    );
  }

  /// Seeds the create form's required ids from the current instructor.
  void seedForCreate({required int? cohortId, required int? instructorId}) {
    state = state.copyWith(cohortId: cohortId, instructorId: instructorId);
  }

  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setDate(DateTime v) => state = state.copyWith(date: v, clearError: true);
  void setStartTime(String v) =>
      state = state.copyWith(startTime: v, clearError: true);
  void setEndTime(String v) =>
      state = state.copyWith(endTime: v, clearError: true);
  void setLocation(String v) =>
      state = state.copyWith(location: v, clearError: true);

  /// Creates (when [classId] is 0) or updates the class.
  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final repo = ref.read(classRepositoryProvider);
    final location =
        state.location.trim().isEmpty ? null : state.location.trim();
    try {
      final ClassSession session;
      if (isEdit) {
        session = await repo.updateClass(
          classId,
          title: state.title.trim(),
          date: state.date,
          startTime: state.startTime,
          endTime: state.endTime,
          location: location,
        );
      } else {
        final cohortId = state.cohortId;
        final instructorId = state.instructorId;
        if (cohortId == null || instructorId == null) {
          state = state.copyWith(
            isSubmitting: false,
            error: '담당 기수 정보가 없어 수업을 생성할 수 없습니다.',
          );
          return;
        }
        session = await repo.createClass(
          cohortId: cohortId,
          instructorId: instructorId,
          title: state.title.trim(),
          date: state.date!,
          startTime: state.startTime,
          endTime: state.endTime,
          location: location,
        );
      }
      state = state.copyWith(isSubmitting: false, saved: session);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final classFormProvider =
    NotifierProvider.family<ClassFormNotifier, ClassFormState, int>(
  ClassFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Career posting create form
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for creating a career posting (admin_ops only).
class CareerFormState {
  const CareerFormState({
    this.postingType = 'job',
    this.title = '',
    this.content = '',
    this.externalUrl = '',
    this.startDate,
    this.endDate,
    this.isSubmitting = false,
    this.error,
    this.saved,
  });

  /// One of `job` / `certification` / `special_lecture`.
  final String postingType;
  final String title;
  final String content;
  final String externalUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the posting is created (drives navigation away).
  final CareerPosting? saved;

  bool get isValid => title.trim().isNotEmpty && content.trim().isNotEmpty;

  CareerFormState copyWith({
    String? postingType,
    String? title,
    String? content,
    String? externalUrl,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    CareerPosting? saved,
  }) {
    return CareerFormState(
      postingType: postingType ?? this.postingType,
      title: title ?? this.title,
      content: content ?? this.content,
      externalUrl: externalUrl ?? this.externalUrl,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

/// Drives the career-posting create form. admin_ops only; a 403 from the
/// backend is surfaced via [CareerFormState.error].
class CareerFormNotifier extends Notifier<CareerFormState> {
  @override
  CareerFormState build() => const CareerFormState();

  void setType(String v) =>
      state = state.copyWith(postingType: v, clearError: true);
  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setContent(String v) =>
      state = state.copyWith(content: v, clearError: true);
  void setExternalUrl(String v) =>
      state = state.copyWith(externalUrl: v, clearError: true);
  void setStartDate(DateTime? v) => state = state.copyWith(
      startDate: v, clearStartDate: v == null, clearError: true);
  void setEndDate(DateTime? v) =>
      state = state.copyWith(endDate: v, clearEndDate: v == null, clearError: true);

  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final posting = await ref.read(classRepositoryProvider).createCareerPosting(
            postingType: state.postingType,
            title: state.title.trim(),
            content: state.content.trim(),
            externalUrl:
                state.externalUrl.trim().isEmpty ? null : state.externalUrl.trim(),
            startDate: state.startDate,
            endDate: state.endDate,
          );
      state = state.copyWith(isSubmitting: false, saved: posting);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final careerFormProvider =
    NotifierProvider<CareerFormNotifier, CareerFormState>(
  CareerFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Course evaluation submission (student)
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for a student's course evaluation: a 1–5 [rating] plus an
/// optional [comment]. The submission is always anonymous to the instructor.
class EvaluationFormState {
  const EvaluationFormState({
    this.rating = 0,
    this.comment = '',
    this.isSubmitting = false,
    this.error,
    this.errorCode,
    this.isSuccess = false,
  });

  /// 0 means "not yet rated"; valid submissions require 1–5.
  final int rating;
  final String comment;
  final bool isSubmitting;
  final String? error;

  /// Backend error code, e.g. `ALREADY_EVALUATED`, for branching the message.
  final String? errorCode;
  final bool isSuccess;

  bool get isValid => rating >= 1 && rating <= 5;

  EvaluationFormState copyWith({
    int? rating,
    String? comment,
    bool? isSubmitting,
    String? error,
    String? errorCode,
    bool clearError = false,
    bool? isSuccess,
  }) {
    return EvaluationFormState(
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Drives a student's course-evaluation form for a class (captured in
/// [classId]). Double submission is blocked through
/// [EvaluationFormState.isSubmitting]; a repeat submission returns
/// `ALREADY_EVALUATED` (409), exposed via [EvaluationFormState.errorCode].
class EvaluationFormNotifier extends Notifier<EvaluationFormState> {
  EvaluationFormNotifier(this.classId);

  final int classId;

  @override
  EvaluationFormState build() => const EvaluationFormState();

  void setRating(int v) => state = state.copyWith(rating: v, clearError: true);
  void setComment(String v) =>
      state = state.copyWith(comment: v, clearError: true);

  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final comment = state.comment.trim().isEmpty ? null : state.comment.trim();
    try {
      await ref.read(classRepositoryProvider).submitEvaluation(
            classId,
            rating: state.rating,
            comment: comment,
          );
      state = state.copyWith(isSubmitting: false, isSuccess: true);
    } on ClassException catch (e) {
      state = state.copyWith(
          isSubmitting: false, error: e.message, errorCode: e.code);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final evaluationFormProvider = NotifierProvider.family<EvaluationFormNotifier,
    EvaluationFormState, int>(
  EvaluationFormNotifier.new,
);
