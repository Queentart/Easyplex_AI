import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_pick.dart';
import '../data/admin_attendance_repository.dart';
import '../domain/admin_attendance_model.dart';
import '../domain/attendance_model.dart';

/// Ops attendance MANAGEMENT (roster) state lives in
/// `attendance_management_provider.dart`; this file owns the CSV import flow
/// (pick → dry-run preview → confirm), import history, and rollback — plus the
/// flat ops records query the OPS DASHBOARD consumes
/// ([adminAttendanceRecordsProvider]).

/// ─────────────────────────────────────────────────────────────────────────
/// Ops flat records query (dashboard) — cohort + type + date filter
/// ─────────────────────────────────────────────────────────────────────────

/// Filter key for the ops flat attendance records query
/// ([adminAttendanceRecordsProvider]).
///
/// `null` fields mean "unfiltered". Const-constructible and value-equal so it
/// can key a Riverpod `family` (e.g. the ops dashboard uses
/// `const AdminAttendanceFilter()` for the all-cohort view). Retained with the
/// same public API the dashboard relied on before the roster refactor.
class AdminAttendanceFilter {
  const AdminAttendanceFilter({
    this.cohortId,
    this.type,
    this.fromDate,
    this.toDate,
  });

  final int? cohortId;
  final AttendanceType? type;

  /// Optional `YYYY-MM-DD` date-range bounds (backend `from_date`/`to_date`).
  final String? fromDate;
  final String? toDate;

  /// Backend wire code for [type], or null when unfiltered.
  String? get typeCode {
    final t = type;
    if (t == null || t == AttendanceType.unknown) return null;
    return t.code;
  }

  @override
  bool operator ==(Object other) =>
      other is AdminAttendanceFilter &&
      other.cohortId == cohortId &&
      other.type == type &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(cohortId, type, fromDate, toDate);
}

/// Loads the ops attendance records for a given [AdminAttendanceFilter]
/// (`GET /attendance/?cohort_id=&type=&from_date=&to_date=`), keyed by the
/// filter. Returns a flat `List<AttendanceRecord>` (newest first), implemented
/// via [AdminAttendanceRepository.getRecords].
///
/// Follows the F2 family pattern (Riverpod 3.x non-codegen): the family
/// argument is captured in the ctor ([filter]) by the provider factory — the
/// no-arg [build] reads it from there.
class AdminAttendanceRecordsNotifier
    extends AsyncNotifier<List<AttendanceRecord>> {
  AdminAttendanceRecordsNotifier(this.filter);

  final AdminAttendanceFilter filter;

  @override
  Future<List<AttendanceRecord>> build() => _fetch();

  Future<List<AttendanceRecord>> _fetch() async {
    final page = await ref.read(adminAttendanceRepositoryProvider).getRecords(
          cohortId: filter.cohortId,
          type: filter.typeCode,
          fromDate: filter.fromDate,
          toDate: filter.toDate,
        );
    return page.records;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final adminAttendanceRecordsProvider = AsyncNotifierProvider.family<
    AdminAttendanceRecordsNotifier,
    List<AttendanceRecord>,
    AdminAttendanceFilter>(
  AdminAttendanceRecordsNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Import history (recent batches → rollback target)
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the CSV import history (`GET /attendance/imports`) so the upload
/// screen can show past batches and offer a rollback.
class ImportHistoryNotifier extends AsyncNotifier<List<ImportLog>> {
  @override
  Future<List<ImportLog>> build() => _fetch();

  Future<List<ImportLog>> _fetch() async {
    final page = await ref.read(adminAttendanceRepositoryProvider).getImportHistory();
    return page.logs;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Rolls back [batchId], then refreshes so the row reflects `rolled_back`.
  /// Throws on failure so the caller can surface the backend message.
  Future<void> rollback(String batchId) async {
    await ref.read(adminAttendanceRepositoryProvider).rollbackImport(batchId);
    await refresh();
  }
}

final importHistoryProvider =
    AsyncNotifierProvider<ImportHistoryNotifier, List<ImportLog>>(
  ImportHistoryNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// CSV file-picker seam
/// ─────────────────────────────────────────────────────────────────────────

/// Picks a CSV file from the device, returning it as a [CsvUpload].
///
/// Backed by the `file_picker` package via [pickFiles], restricted to `.csv`
/// and invoked with `withData: true` so bytes are available on Flutter Web.
/// Returns null when the user cancels, so the upload screen treats cancellation
/// as a no-op and keeps the text-paste fallback available.
typedef CsvPickerFn = Future<CsvUpload?> Function();

final adminCsvPickerProvider = Provider<CsvPickerFn>(
  (ref) => () async {
    final picked = await pickFiles(extensions: ['csv']);
    if (picked.isEmpty) return null;
    final file = picked.first;
    return CsvUpload(fileName: file.fileName, bytes: file.bytes);
  },
);

/// Thrown by CSV-picking helpers when a picker is unavailable. Retained for
/// backward compatibility with callers that still catch it; the wired
/// [adminCsvPickerProvider] no longer throws this (it returns null on cancel).
class CsvPickerUnavailable implements Exception {
  const CsvPickerUnavailable();

  @override
  String toString() => '파일 선택 기능을 준비 중입니다. CSV 내용을 붙여넣어 업로드할 수 있습니다.';
}

/// ─────────────────────────────────────────────────────────────────────────
/// CSV import flow state (pick → dry-run preview → confirm → committed)
/// ─────────────────────────────────────────────────────────────────────────

/// Phase of the CSV import wizard.
enum CsvImportPhase {
  /// No file selected yet — the user picks a file or pastes CSV.
  idle,

  /// A dry-run preview is being requested from the server.
  previewing,

  /// A dry-run preview is loaded; awaiting the user's confirm.
  preview,

  /// The confirmed import is being committed.
  committing,

  /// The import was committed.
  committed,
}

/// Immutable state for the CSV import wizard.
class CsvImportState {
  const CsvImportState({
    this.cohortId,
    this.upload,
    this.phase = CsvImportPhase.idle,
    this.preview,
    this.committed,
    this.error,
  });

  /// Target cohort for the import (required before any server call).
  final int? cohortId;

  /// The selected/pasted CSV, if any.
  final CsvUpload? upload;

  final CsvImportPhase phase;

  /// The most recent dry-run result (preview rows + would-be counts).
  final ImportResult? preview;

  /// The committed import result (set once [phase] == committed).
  final ImportResult? committed;

  /// User-facing error message from the last failed step.
  final String? error;

  bool get canPreview =>
      cohortId != null &&
      upload != null &&
      (phase == CsvImportPhase.idle || phase == CsvImportPhase.preview);
  bool get isBusy =>
      phase == CsvImportPhase.previewing || phase == CsvImportPhase.committing;
  bool get hasFile => upload != null;

  CsvImportState copyWith({
    int? cohortId,
    CsvUpload? upload,
    CsvImportPhase? phase,
    ImportResult? preview,
    ImportResult? committed,
    String? error,
    bool clearUpload = false,
    bool clearPreview = false,
    bool clearError = false,
  }) {
    return CsvImportState(
      cohortId: cohortId ?? this.cohortId,
      upload: clearUpload ? null : (upload ?? this.upload),
      phase: phase ?? this.phase,
      preview: clearPreview ? null : (preview ?? this.preview),
      committed: committed ?? this.committed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the CSV import wizard: select a target cohort + a CSV, run a server
/// dry-run to preview, then commit. Surfaces errors via [CsvImportState.error]
/// instead of throwing so the screen stays simple.
class CsvImportNotifier extends Notifier<CsvImportState> {
  @override
  CsvImportState build() => const CsvImportState();

  void setCohortId(int? cohortId) =>
      state = state.copyWith(cohortId: cohortId, clearError: true);

  /// Registers a picked/pasted [upload], resetting any prior preview.
  void setUpload(CsvUpload upload) => state = state.copyWith(
        upload: upload,
        phase: CsvImportPhase.idle,
        clearPreview: true,
        clearError: true,
      );

  /// Clears the selected file + preview, returning to the idle phase.
  void reset() => state = const CsvImportState();

  /// Step 1: dry-run preview (`dry_run=true`) — describes what *would* change
  /// without writing. Stores the result and moves to the preview phase.
  Future<void> preview() async {
    final cohortId = state.cohortId;
    final upload = state.upload;
    if (cohortId == null || upload == null || state.isBusy) return;

    state = state.copyWith(
      phase: CsvImportPhase.previewing,
      clearError: true,
      clearPreview: true,
    );
    try {
      final result = await ref.read(adminAttendanceRepositoryProvider).importCsv(
            upload: upload,
            cohortId: cohortId,
            dryRun: true,
          );
      state = state.copyWith(phase: CsvImportPhase.preview, preview: result);
    } catch (e) {
      state = state.copyWith(phase: CsvImportPhase.idle, error: e.toString());
    }
  }

  /// Step 2: commit (`dry_run=false`) the previewed file. Only valid after a
  /// successful [preview]. On success moves to the committed phase and
  /// invalidates the import-history list so the new batch appears.
  Future<void> confirm() async {
    final cohortId = state.cohortId;
    final upload = state.upload;
    if (cohortId == null ||
        upload == null ||
        state.phase != CsvImportPhase.preview) {
      return;
    }

    state = state.copyWith(phase: CsvImportPhase.committing, clearError: true);
    try {
      final result = await ref.read(adminAttendanceRepositoryProvider).importCsv(
            upload: upload,
            cohortId: cohortId,
            dryRun: false,
          );
      state = state.copyWith(phase: CsvImportPhase.committed, committed: result);
      ref.invalidate(importHistoryProvider);
    } catch (e) {
      state = state.copyWith(phase: CsvImportPhase.preview, error: e.toString());
    }
  }
}

final csvImportProvider =
    NotifierProvider<CsvImportNotifier, CsvImportState>(CsvImportNotifier.new);
