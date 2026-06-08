import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/leave_repository.dart';
import '../domain/leave_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// List
/// ─────────────────────────────────────────────────────────────────────────

/// The student's own leave-request list (server filters to the caller).
///
/// Uses [AsyncNotifier] so the UI gets loading / error / data for free, with a
/// [refresh] for pull-to-refresh and an [optimisticallyCancel] for snappy
/// cancellation feedback.
class LeaveListNotifier extends AsyncNotifier<List<LeaveRequest>> {
  @override
  Future<List<LeaveRequest>> build() => _fetch();

  Future<List<LeaveRequest>> _fetch() async {
    final repo = ref.read(leaveRepositoryProvider);
    final page = await repo.list(size: 100);
    return page.items;
  }

  /// Re-fetches the list, surfacing errors through [state].
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Cancels a pending request with an optimistic removal-of-pending update.
  ///
  /// On success the canceled row is reflected immediately (status flips to
  /// canceled); on failure the previous list is restored and the error is
  /// rethrown so the screen can show a SnackBar.
  Future<void> cancel(int id) async {
    final previous = state.value;
    if (previous != null) {
      // Optimistic: mark the row canceled locally for instant feedback.
      state = AsyncData([
        for (final r in previous)
          if (r.id == id) _markCanceled(r) else r,
      ]);
    }

    try {
      await ref.read(leaveRepositoryProvider).cancel(id);
      // Re-sync with the server (authoritative status / ordering).
      state = await AsyncValue.guard(_fetch);
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  LeaveRequest _markCanceled(LeaveRequest r) => LeaveRequest(
        id: r.id,
        cohortId: r.cohortId,
        studentId: r.studentId,
        type: r.type,
        targetDate: r.targetDate,
        startTime: r.startTime,
        reason: r.reason,
        status: LeaveStatus.canceled,
        reviewedBy: r.reviewedBy,
        reviewedAt: r.reviewedAt,
        reviewComment: r.reviewComment,
        createdAt: r.createdAt,
      );
}

final leaveListProvider =
    AsyncNotifierProvider<LeaveListNotifier, List<LeaveRequest>>(
  LeaveListNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Balance (allowance / remaining)
/// ─────────────────────────────────────────────────────────────────────────

/// The current user's own leave allowance + usage summary.
///
/// Backed by `GET /leave-requests/balance`. Read-only, so a plain
/// [FutureProvider] is enough; the UI consumes its [AsyncValue] directly.
final leaveBalanceProvider = FutureProvider<LeaveBalance>((ref) async {
  return ref.read(leaveRepositoryProvider).getBalance();
});

/// ─────────────────────────────────────────────────────────────────────────
/// Detail
/// ─────────────────────────────────────────────────────────────────────────

/// Single leave request by id. Family keyed on the request id.
final leaveDetailProvider =
    FutureProvider.family<LeaveRequest, int>((ref, id) async {
  return ref.read(leaveRepositoryProvider).getById(id);
});

/// ─────────────────────────────────────────────────────────────────────────
/// Create form
/// ─────────────────────────────────────────────────────────────────────────

/// Immutable view-state for the create form.
class LeaveFormState {
  const LeaveFormState({
    this.type = LeaveType.earlyLeave,
    this.targetDate,
    this.startTime,
    this.reason = '',
    this.evidence,
    this.isUploading = false,
    this.isSubmitting = false,
    this.error,
  });

  final LeaveType type;
  final DateTime? targetDate;

  /// Only relevant for [LeaveType.earlyLeave].
  final TimeOfDayValue? startTime;

  final String reason;
  final UploadedFile? evidence;

  /// True while a supporting document is being uploaded.
  final bool isUploading;

  /// True while the create request is in flight (disables submit).
  final bool isSubmitting;

  /// Last error message (cleared on the next edit).
  final String? error;

  bool get requiresStartTime => type == LeaveType.earlyLeave;

  /// Ready to submit: date chosen, reason non-empty, (early-leave) time chosen,
  /// and nothing currently in flight.
  bool get isValid {
    if (targetDate == null) return false;
    if (reason.trim().isEmpty) return false;
    if (requiresStartTime && startTime == null) return false;
    return !isSubmitting && !isUploading;
  }

  LeaveFormState copyWith({
    LeaveType? type,
    DateTime? targetDate,
    TimeOfDayValue? startTime,
    bool clearStartTime = false,
    String? reason,
    UploadedFile? evidence,
    bool clearEvidence = false,
    bool? isUploading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return LeaveFormState(
      type: type ?? this.type,
      targetDate: targetDate ?? this.targetDate,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      reason: reason ?? this.reason,
      evidence: clearEvidence ? null : (evidence ?? this.evidence),
      isUploading: isUploading ?? this.isUploading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the create-form view-state and submission.
class LeaveFormNotifier extends Notifier<LeaveFormState> {
  @override
  LeaveFormState build() => const LeaveFormState();

  /// Applies prefill values (from navigation query params) in one shot.
  ///
  /// Used by the form screen on first build when arriving from e.g. the
  /// attendance exceptions list. Skips empty prefills so a plain "new request"
  /// visit keeps the default state. The start time is only adopted for 조퇴
  /// (the only type that uses it).
  void seed(LeaveFormPrefill prefill) {
    if (prefill.isEmpty) return;
    final type = prefill.type ?? state.type;
    final usesStartTime = type == LeaveType.earlyLeave;
    state = state.copyWith(
      type: type,
      targetDate: prefill.targetDate,
      startTime: usesStartTime ? prefill.startTime : null,
      clearStartTime: !usesStartTime,
      clearError: true,
    );
  }

  void setType(LeaveType type) {
    // Clear the start time when switching away from 조퇴 (it's only used there).
    if (type != LeaveType.earlyLeave) {
      state = state.copyWith(type: type, clearStartTime: true, clearError: true);
    } else {
      state = state.copyWith(type: type, clearError: true);
    }
  }

  void setTargetDate(DateTime date) =>
      state = state.copyWith(targetDate: date, clearError: true);

  void setStartTime(TimeOfDayValue time) =>
      state = state.copyWith(startTime: time, clearError: true);

  void setReason(String reason) =>
      state = state.copyWith(reason: reason, clearError: true);

  void removeEvidence() => state = state.copyWith(clearEvidence: true);

  /// Uploads a supporting document via the presign → PUT flow, storing the
  /// resulting [UploadedFile] reference on the form.
  Future<void> uploadEvidence({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final uploaded = await ref.read(leaveRepositoryProvider).uploadEvidence(
            fileName: fileName,
            bytes: bytes,
            contentType: contentType,
          );
      state = state.copyWith(evidence: uploaded, isUploading: false);
    } on LeaveException catch (e) {
      state = state.copyWith(isUploading: false, error: e.message);
    } catch (_) {
      state =
          state.copyWith(isUploading: false, error: '첨부파일 업로드에 실패했습니다.');
    }
  }

  /// Submits the create request. Returns the created request on success, or
  /// null on failure (the error is exposed via [LeaveFormState.error]).
  ///
  /// Guards against duplicate submission via [LeaveFormState.isSubmitting].
  Future<LeaveRequest?> submit() async {
    if (!state.isValid) return null;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final created = await ref.read(leaveRepositoryProvider).create(
            LeaveRequestCreate(
              type: state.type,
              targetDate: state.targetDate!,
              reason: state.reason.trim(),
              startTime: state.requiresStartTime ? state.startTime : null,
              evidence: state.evidence,
            ),
          );
      state = state.copyWith(isSubmitting: false);
      // Refresh the list so the new request shows on return.
      ref.invalidate(leaveListProvider);
      return created;
    } on LeaveException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(isSubmitting: false, error: '신청을 처리하지 못했습니다.');
      return null;
    }
  }
}

final leaveFormProvider =
    NotifierProvider<LeaveFormNotifier, LeaveFormState>(LeaveFormNotifier.new);

/// ─────────────────────────────────────────────────────────────────────────
/// Reviewer (operations-team / instructor) list + approve / reject
/// ─────────────────────────────────────────────────────────────────────────

/// Status filter for the reviewer list.
///
/// `all` means "no `status` query param"; the others map onto the backend
/// `pending` / `approved` / `rejected` values. (Canceled requests are reachable
/// only via [LeaveStatus.canceled] and are intentionally not a filter chip —
/// reviewers care about pending / approved / rejected.)
enum LeaveReviewFilter {
  all(null, '전체'),
  pending(LeaveStatus.pending, '대기'),
  approved(LeaveStatus.approved, '승인'),
  rejected(LeaveStatus.rejected, '반려');

  const LeaveReviewFilter(this.status, this.label);

  /// The status to filter by, or null for "all".
  final LeaveStatus? status;

  /// Korean chip label.
  final String label;
}

/// Holds the active reviewer-list filter. Defaults to `pending` (the reviewer's
/// primary job). Changing it re-runs [LeaveReviewListNotifier.build].
class LeaveReviewFilterNotifier extends Notifier<LeaveReviewFilter> {
  @override
  LeaveReviewFilter build() => LeaveReviewFilter.pending;

  void select(LeaveReviewFilter filter) => state = filter;
}

/// The active filter for the reviewer list. Changing it re-runs the fetch.
final leaveReviewFilterProvider =
    NotifierProvider<LeaveReviewFilterNotifier, LeaveReviewFilter>(
  LeaveReviewFilterNotifier.new,
);

/// Reviewer-facing leave-request list.
///
/// Reuses [LeaveRepository.list]; the backend already scopes the rows to the
/// caller's authority (operations-team sees the institution's requests,
/// instructors see only their own cohort's). The selected
/// [leaveReviewFilterProvider] is applied as the `status` query param so the
/// list reflects the chosen tab.
///
/// Defaults to the `pending` filter because that is the reviewer's primary job;
/// pending rows are also visually highlighted in the list screen.
class LeaveReviewListNotifier extends AsyncNotifier<List<LeaveRequest>> {
  @override
  Future<List<LeaveRequest>> build() {
    // Re-fetch whenever the filter changes.
    final filter = ref.watch(leaveReviewFilterProvider);
    return _fetch(filter);
  }

  Future<List<LeaveRequest>> _fetch(LeaveReviewFilter filter) async {
    final repo = ref.read(leaveRepositoryProvider);
    final page = await repo.list(status: filter.status, size: 100);
    return page.items;
  }

  /// Re-fetches with the current filter, surfacing errors through [state].
  Future<void> refresh() async {
    final filter = ref.read(leaveReviewFilterProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(filter));
  }

  /// Approves [id] with a (required) [reviewComment].
  ///
  /// Optimistically flips the row to approved for instant feedback, calls the
  /// backend, then re-syncs with the server (authoritative status). On failure
  /// the previous list is restored and the [LeaveException] is rethrown so the
  /// screen can show it. Returns the server's updated request on success.
  Future<LeaveRequest> approve(int id, String reviewComment) {
    return _review(
      id,
      LeaveStatus.approved,
      (repo) => repo.approve(id, reviewComment),
    );
  }

  /// Rejects [id] with a (required) [reviewComment]. See [approve].
  Future<LeaveRequest> reject(int id, String reviewComment) {
    return _review(
      id,
      LeaveStatus.rejected,
      (repo) => repo.reject(id, reviewComment),
    );
  }

  Future<LeaveRequest> _review(
    int id,
    LeaveStatus optimisticStatus,
    Future<LeaveRequest> Function(LeaveRepository repo) call,
  ) async {
    final previous = state.value;
    final filter = ref.read(leaveReviewFilterProvider);

    if (previous != null) {
      // Optimistic: reflect the new status locally for instant feedback.
      state = AsyncData([
        for (final r in previous)
          if (r.id == id) _withStatus(r, optimisticStatus) else r,
      ]);
    }

    try {
      final updated = await call(ref.read(leaveRepositoryProvider));
      // Re-sync with the server (the row may now fall outside the active
      // filter — e.g. an approved request leaving the "대기" tab).
      state = await AsyncValue.guard(() => _fetch(filter));
      // Keep the detail view (if open) in step.
      ref.invalidate(leaveDetailProvider(id));
      return updated;
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  LeaveRequest _withStatus(LeaveRequest r, LeaveStatus status) => LeaveRequest(
        id: r.id,
        cohortId: r.cohortId,
        studentId: r.studentId,
        type: r.type,
        targetDate: r.targetDate,
        startTime: r.startTime,
        reason: r.reason,
        status: status,
        reviewedBy: r.reviewedBy,
        reviewedAt: r.reviewedAt,
        reviewComment: r.reviewComment,
        createdAt: r.createdAt,
      );
}

final leaveReviewListProvider =
    AsyncNotifierProvider<LeaveReviewListNotifier, List<LeaveRequest>>(
  LeaveReviewListNotifier.new,
);
