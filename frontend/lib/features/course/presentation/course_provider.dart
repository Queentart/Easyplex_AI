import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_pick.dart';
import '../data/course_repository.dart';
import '../domain/course_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Course list (instructor — server-scoped to taught cohorts)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the course list visible to the current instructor. The backend scopes
/// results to the instructor's taught cohorts, so no cohort filter is passed.
/// Newest first.
class CourseListNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() => _fetch();

  Future<List<Course>> _fetch() async {
    final page =
        await ref.read(courseRepositoryProvider).listCourses(page: 1, size: 50);
    return page.items;
  }

  /// Pull-to-refresh / retry entry point.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final courseListProvider =
    AsyncNotifierProvider<CourseListNotifier, List<Course>>(
  CourseListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Single course detail (metadata only — videos load via courseVideosProvider)
/// ─────────────────────────────────────────────────────────────────────────

final courseDetailProvider =
    FutureProvider.family.autoDispose<Course, int>((ref, courseId) async {
  return ref.read(courseRepositoryProvider).getCourse(courseId);
});

/// ─────────────────────────────────────────────────────────────────────────
/// Course videos (per course)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the videos for a course (captured in [courseId]).
///
/// Family argument is captured by the provider factory — Riverpod 3.x
/// non-codegen notifiers don't receive the argument in [build].
class CourseVideosNotifier extends AsyncNotifier<List<CourseVideo>> {
  CourseVideosNotifier(this.courseId);

  final int courseId;

  @override
  Future<List<CourseVideo>> build() => _fetch();

  Future<List<CourseVideo>> _fetch() =>
      ref.read(courseRepositoryProvider).listVideos(courseId);

  /// Reloads the video list (after an add / delete).
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final courseVideosProvider = AsyncNotifierProvider.family<CourseVideosNotifier,
    List<CourseVideo>, int>(
  CourseVideosNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Course day-logs (수업일지, per course)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the day-logs for a course (captured in [courseId]) so the detail
/// screen can show which days already have a 수업일지.
///
/// Family argument is captured by the provider factory — Riverpod 3.x
/// non-codegen notifiers don't receive the argument in [build].
class CourseDayLogsNotifier extends AsyncNotifier<List<CourseDayLog>> {
  CourseDayLogsNotifier(this.courseId);

  final int courseId;

  @override
  Future<List<CourseDayLog>> build() => _fetch();

  Future<List<CourseDayLog>> _fetch() =>
      ref.read(courseRepositoryProvider).listDayLogs(courseId);

  /// Reloads the day-log list (after an upsert).
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final courseDayLogsProvider = AsyncNotifierProvider.family<
    CourseDayLogsNotifier, List<CourseDayLog>, int>(
  CourseDayLogsNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Course create / edit form
/// ─────────────────────────────────────────────────────────────────────────

/// Form state for creating or editing a course.
///
/// On create, [cohortId] is required (chosen from the instructor's taught
/// cohorts). [status] is only editable in edit mode.
class CourseFormState {
  const CourseFormState({
    this.title = '',
    this.description = '',
    this.startDate,
    this.endDate,
    this.cohortId,
    this.status = CourseStatus.active,
    this.isSubmitting = false,
    this.error,
    this.saved,
  });

  final String title;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? cohortId;
  final CourseStatus status;
  final bool isSubmitting;
  final String? error;

  /// Non-null once the course is created / updated (drives navigation away).
  final Course? saved;

  /// end_date must be >= start_date (client mirror of the backend 422 check).
  bool get datesValid {
    final s = startDate;
    final e = endDate;
    if (s == null || e == null) return false;
    return !e.isBefore(s);
  }

  bool get isValid =>
      title.trim().isNotEmpty && cohortId != null && datesValid;

  CourseFormState copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? cohortId,
    CourseStatus? status,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Course? saved,
  }) {
    return CourseFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cohortId: cohortId ?? this.cohortId,
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

/// Drives the course create / edit form. The family argument [courseId] is `0`
/// for create mode and the target course id for edit mode.
///
/// Double submission is blocked through [CourseFormState.isSubmitting]; on
/// success [CourseFormState.saved] holds the persisted course so the screen can
/// navigate back and the caller can invalidate the list.
class CourseFormNotifier extends Notifier<CourseFormState> {
  CourseFormNotifier(this.courseId);

  /// 0 = create, otherwise the course being edited.
  final int courseId;

  bool get isEdit => courseId > 0;

  @override
  CourseFormState build() => const CourseFormState();

  /// Pre-fills the form from an existing course (edit mode).
  void seed(Course course) {
    state = CourseFormState(
      title: course.title,
      description: course.description ?? '',
      startDate: course.startDate,
      endDate: course.endDate,
      cohortId: course.cohortId,
      status: course.status == CourseStatus.unknown
          ? CourseStatus.active
          : course.status,
    );
  }

  /// Seeds the create form's default cohort (e.g. the instructor's first taught
  /// cohort) when one is available.
  void seedCohort(int? cohortId) {
    if (cohortId == null) return;
    state = state.copyWith(cohortId: cohortId);
  }

  void setTitle(String v) => state = state.copyWith(title: v, clearError: true);
  void setDescription(String v) =>
      state = state.copyWith(description: v, clearError: true);
  void setStartDate(DateTime v) =>
      state = state.copyWith(startDate: v, clearError: true);
  void setEndDate(DateTime v) =>
      state = state.copyWith(endDate: v, clearError: true);
  void setCohortId(int? v) =>
      state = state.copyWith(cohortId: v, clearError: true);
  void setStatus(CourseStatus v) =>
      state = state.copyWith(status: v, clearError: true);

  /// Creates (when [courseId] is 0) or updates the course.
  Future<void> submit() async {
    if (!state.isValid || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final repo = ref.read(courseRepositoryProvider);
    final description =
        state.description.trim().isEmpty ? null : state.description.trim();
    try {
      final Course course;
      if (isEdit) {
        course = await repo.updateCourse(
          courseId,
          title: state.title.trim(),
          description: description,
          startDate: state.startDate,
          endDate: state.endDate,
          status: state.status,
        );
      } else {
        final cohortId = state.cohortId;
        if (cohortId == null) {
          state = state.copyWith(
            isSubmitting: false,
            error: '담당 기수를 선택해 주세요.',
          );
          return;
        }
        course = await repo.createCourse(
          cohortId: cohortId,
          title: state.title.trim(),
          description: description,
          startDate: state.startDate!,
          endDate: state.endDate!,
        );
      }
      state = state.copyWith(isSubmitting: false, saved: course);
    } on CourseException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final courseFormProvider =
    NotifierProvider.family<CourseFormNotifier, CourseFormState, int>(
  CourseFormNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Video upload action (per course)
/// ─────────────────────────────────────────────────────────────────────────

/// Allowed video file extensions for the picker (drives `FileType.custom`).
const List<String> kCourseVideoExtensions = [
  'mp4',
  'mov',
  'webm',
  'mkv',
  'avi',
  'm4v',
];

/// Transient upload state for one course, keyed by [courseId].
///
/// [uploadingDate] marks which day's "영상 추가" button should show a busy
/// state; null means idle. [error] surfaces the last failure (cleared on the
/// next attempt).
class CourseUploadState {
  const CourseUploadState({this.uploadingDate, this.error});

  /// The day currently uploading (date-only), or null when idle.
  final DateTime? uploadingDate;
  final String? error;

  bool get isUploading => uploadingDate != null;

  /// True when an upload is in progress for the given [day] (date-only compare).
  bool isUploadingFor(DateTime day) {
    final d = uploadingDate;
    if (d == null) return false;
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

  CourseUploadState copyWith({
    DateTime? uploadingDate,
    bool clearUploading = false,
    String? error,
    bool clearError = false,
  }) {
    return CourseUploadState(
      uploadingDate:
          clearUploading ? null : (uploadingDate ?? this.uploadingDate),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the pick → presign+upload → addVideo → reload flow for a course
/// (captured in [courseId]).
class CourseUploadNotifier extends Notifier<CourseUploadState> {
  CourseUploadNotifier(this.courseId);

  final int courseId;

  @override
  CourseUploadState build() => const CourseUploadState();

  /// Picks a video file then uploads + registers it against [classDate].
  ///
  /// Returns true on success (one video added), false on cancel or failure.
  /// No-op while another upload is already in progress.
  Future<bool> pickAndUpload(DateTime classDate) async {
    if (state.isUploading) return false;
    state = state.copyWith(uploadingDate: classDate, clearError: true);

    final repo = ref.read(courseRepositoryProvider);
    try {
      final picked = await pickFiles(extensions: kCourseVideoExtensions);
      if (picked.isEmpty) {
        // User cancelled — treat as a graceful no-op.
        state = state.copyWith(clearUploading: true);
        return false;
      }
      final file = picked.first;
      final fileKey = await repo.presignAndUpload(
        fileName: file.fileName,
        contentType: file.contentType,
        bytes: file.bytes,
      );
      await repo.addVideo(
        courseId,
        classDate: classDate,
        fileKey: fileKey,
        originalFilename: file.fileName,
        contentType: file.contentType,
        sizeBytes: file.size,
      );
      state = state.copyWith(clearUploading: true);
      // Reload the day's videos so the new one appears.
      await ref.read(courseVideosProvider(courseId).notifier).reload();
      return true;
    } on CourseException catch (e) {
      state = state.copyWith(clearUploading: true, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        clearUploading: true,
        error: '영상 업로드 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }

  /// Uploads an in-memory video file (e.g. a drag-and-dropped file) against
  /// [classDate], mirroring [pickAndUpload] but for bytes that are already in
  /// hand. Returns true on success.
  ///
  /// No-op while another upload is already in progress.
  Future<bool> uploadBytes(
    DateTime classDate,
    String fileName,
    Uint8List bytes,
    String contentType,
  ) async {
    if (state.isUploading) return false;
    if (bytes.isEmpty) return false;
    state = state.copyWith(uploadingDate: classDate, clearError: true);

    final repo = ref.read(courseRepositoryProvider);
    try {
      final fileKey = await repo.presignAndUpload(
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
      );
      await repo.addVideo(
        courseId,
        classDate: classDate,
        fileKey: fileKey,
        originalFilename: fileName,
        contentType: contentType,
        sizeBytes: bytes.length,
      );
      state = state.copyWith(clearUploading: true);
      await ref.read(courseVideosProvider(courseId).notifier).reload();
      return true;
    } on CourseException catch (e) {
      state = state.copyWith(clearUploading: true, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        clearUploading: true,
        error: '영상 업로드 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }

  /// Deletes a video then reloads the list. Returns true on success.
  Future<bool> deleteVideo(int videoId) async {
    try {
      await ref.read(courseRepositoryProvider).deleteVideo(courseId, videoId);
      await ref.read(courseVideosProvider(courseId).notifier).reload();
      return true;
    } on CourseException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: '영상 삭제 중 오류가 발생했습니다.');
      return false;
    }
  }
}

final courseUploadProvider =
    NotifierProvider.family<CourseUploadNotifier, CourseUploadState, int>(
  CourseUploadNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Day-log editor (수업일지 save action, per course + day)
/// ─────────────────────────────────────────────────────────────────────────

/// Family key for [courseDayLogEditProvider]: the target course + class date.
///
/// Records are value-equal in Dart, so the same (courseId, date) always maps to
/// the same notifier instance.
typedef DayLogKey = ({int courseId, DateTime date});

/// Transient state for the 수업일지 save action of one (course, day).
class DayLogEditState {
  const DayLogEditState({this.isSaving = false, this.saved = false, this.error});

  final bool isSaving;

  /// True after the most recent save succeeded (drives the "저장되었습니다" hint).
  final bool saved;
  final String? error;

  DayLogEditState copyWith({
    bool? isSaving,
    bool? saved,
    String? error,
    bool clearError = false,
  }) {
    return DayLogEditState(
      isSaving: isSaving ?? this.isSaving,
      saved: saved ?? this.saved,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the upsert of one day's 수업일지. On success it reloads
/// [courseDayLogsProvider] so the course detail's "일지" indicator updates.
class CourseDayLogEditNotifier extends Notifier<DayLogEditState> {
  CourseDayLogEditNotifier(this.key);

  final DayLogKey key;

  @override
  DayLogEditState build() => const DayLogEditState();

  /// Upserts [content] for this notifier's (course, day). Returns true on
  /// success. Blocks double submission.
  Future<bool> save(String content) async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true, saved: false, clearError: true);
    try {
      await ref.read(courseRepositoryProvider).upsertDayLog(
            key.courseId,
            classDate: key.date,
            content: content,
          );
      state = state.copyWith(isSaving: false, saved: true);
      await ref.read(courseDayLogsProvider(key.courseId).notifier).reload();
      return true;
    } on CourseException catch (e) {
      state = state.copyWith(isSaving: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isSaving: false, error: '수업 일지 저장 중 오류가 발생했습니다.');
      return false;
    }
  }

  /// Clears the transient "saved" hint (e.g. once the user edits again).
  void clearSaved() {
    if (state.saved) state = state.copyWith(saved: false);
  }
}

final courseDayLogEditProvider = NotifierProvider.family<
    CourseDayLogEditNotifier, DayLogEditState, DayLogKey>(
  CourseDayLogEditNotifier.new,
);
