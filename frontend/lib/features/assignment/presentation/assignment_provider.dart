import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_pick.dart';
import '../data/assignment_repository.dart';
import '../domain/assignment_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Assignment list (student's own cohort)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the signed-in student's assignment list. The backend scopes results
/// to the student's cohort automatically, so no cohort filter is passed here.
class AssignmentListNotifier extends AsyncNotifier<List<Assignment>> {
  @override
  Future<List<Assignment>> build() => _fetch();

  Future<List<Assignment>> _fetch() async {
    final repo = ref.read(assignmentRepositoryProvider);
    final page = await repo.listAssignments(page: 1, size: 50);
    final items = [...page.items];
    // Soonest-due, still-open assignments first so deadlines stay front of mind;
    // closed / overdue ones sink to the bottom.
    items.sort((a, b) {
      final ao = a.canSubmit() ? 0 : 1;
      final bo = b.canSubmit() ? 0 : 1;
      if (ao != bo) return ao - bo;
      return a.dueDate.compareTo(b.dueDate);
    });
    return items;
  }

  /// Pull-to-refresh / retry entry point.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final assignmentListProvider =
    AsyncNotifierProvider<AssignmentListNotifier, List<Assignment>>(
  AssignmentListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Single assignment detail
/// ─────────────────────────────────────────────────────────────────────────

/// Loads one assignment by id for the detail screen.
final assignmentDetailProvider =
    FutureProvider.family<Assignment, int>((ref, assignmentId) async {
  final repo = ref.read(assignmentRepositoryProvider);
  return repo.getAssignment(assignmentId);
});

/// ─────────────────────────────────────────────────────────────────────────
/// Submission form state
/// ─────────────────────────────────────────────────────────────────────────

/// Picks one or more files from the device, returning them as [PendingFile]s.
///
/// Backed by the `file_picker` package via [pickFiles] (`withData: true`, so
/// bytes are available on Flutter Web). Returns an empty list when the user
/// cancels the dialog, so the submission screen treats cancellation as a no-op.
typedef FilePickerFn = Future<List<PendingFile>> Function();

final assignmentFilePickerProvider = Provider<FilePickerFn>(
  (ref) => () async {
    final picked = await pickFiles(multiple: true);
    return [
      for (final file in picked)
        PendingFile(
          fileName: file.fileName,
          contentType: file.contentType,
          bytes: file.bytes,
        ),
    ];
  },
);

/// Thrown by file-picking helpers when a picker is unavailable. Retained for
/// backward compatibility with callers that still catch it; the wired
/// [assignmentFilePickerProvider] no longer throws this (it returns an empty
/// list on cancel instead).
class FilePickerUnavailable implements Exception {
  const FilePickerUnavailable();

  @override
  String toString() => '파일 첨부 기능을 준비 중입니다.';
}

/// A file the student has picked but not yet uploaded.
class PendingFile {
  const PendingFile({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;

  int get size => bytes.length;
}

/// Transient state of the submission form.
class SubmissionFormState {
  const SubmissionFormState({
    this.content = '',
    this.files = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.submitted,
  });

  /// Free-text body of the submission.
  final String content;

  /// Files staged for upload. The backend accepts one file per submission call;
  /// the notifier uploads + submits these sequentially (see [submit]).
  final List<PendingFile> files;

  final bool isSubmitting;
  final String? errorMessage;

  /// Set when the submission succeeds (drives the success SnackBar + reload).
  final Submission? submitted;

  bool get hasContent => content.trim().isNotEmpty;

  /// At least some content (text or a file) is required to submit.
  bool get canSubmit => hasContent || files.isNotEmpty;

  SubmissionFormState copyWith({
    String? content,
    List<PendingFile>? files,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    Submission? submitted,
  }) {
    return SubmissionFormState(
      content: content ?? this.content,
      files: files ?? this.files,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitted: submitted ?? this.submitted,
    );
  }

  static const initial = SubmissionFormState();
}

/// Drives the submission flow for one assignment:
///   1. upload each staged file (presign → PUT S3) → [SubmissionFileRef]
///   2. POST the submission (content + first file), then POST each remaining
///      file (the backend upserts the submission and appends each file).
///
/// Prevents duplicate submits and surfaces a clean Korean error message.
class SubmissionFormNotifier extends Notifier<SubmissionFormState> {
  SubmissionFormNotifier(this._assignmentId);

  final int _assignmentId;

  @override
  SubmissionFormState build() => SubmissionFormState.initial;

  void setContent(String value) {
    state = state.copyWith(content: value, clearError: true);
  }

  void addFile(PendingFile file) {
    state = state.copyWith(files: [...state.files, file], clearError: true);
  }

  void removeFileAt(int index) {
    if (index < 0 || index >= state.files.length) return;
    final next = [...state.files]..removeAt(index);
    state = state.copyWith(files: next);
  }

  /// Submits the form. Returns true on success; on failure stores the error and
  /// returns false. No-op while already submitting or when nothing to submit.
  Future<bool> submit() async {
    if (state.isSubmitting || !state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);

    final repo = ref.read(assignmentRepositoryProvider);
    try {
      // 1. Upload every staged file first.
      final uploaded = <SubmissionFileRef>[];
      for (final file in state.files) {
        uploaded.add(await repo.uploadSubmissionFile(
          fileName: file.fileName,
          contentType: file.contentType,
          bytes: file.bytes,
        ));
      }

      // 2. First call carries the text content + first file (if any). The
      //    backend upserts one Submission and appends one SubmissionFile per
      //    call, so remaining files are sent in follow-up calls.
      final content = state.hasContent ? state.content.trim() : null;
      Submission result;
      if (uploaded.isEmpty) {
        result = await repo.submit(_assignmentId, content: content);
      } else {
        result = await repo.submit(
          _assignmentId,
          content: content,
          file: uploaded.first,
        );
        for (final file in uploaded.skip(1)) {
          result = await repo.submit(_assignmentId, file: file);
        }
      }

      state = state.copyWith(isSubmitting: false, submitted: result);
      return true;
    } on AssignmentException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '제출 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }
}

final submissionFormProvider = NotifierProvider.family<SubmissionFormNotifier,
    SubmissionFormState, int>(SubmissionFormNotifier.new);
