/// Domain models for the OPERATIONS-TEAM (admin_ops) attendance management
/// feature: CSV import (dry-run preview + confirm), import history, rollback.
///
/// These mirror the backend response shapes exactly
/// (`backend/app/schemas/attendance.py`):
///   - [ImportResult]   ← `ImportResult`  (POST /attendance/import)
///   - [ImportPreviewRow] ← one entry of `ImportResult.preview` (free-form dict)
///   - [ImportLog]      ← `ImportLogOut`  (GET /attendance/imports, paginated)
///
/// The per-date record + cohort summary shapes are NOT redefined here: the ops
/// table reuses [AttendanceRecord]/[AttendanceSummary] from
/// `attendance_model.dart`. This layer holds NO business logic — it only
/// decodes the wire JSON.
library;

import 'dart:convert';

/// Result of a CSV import call (`POST /attendance/import`).
///
/// The same shape is returned for both a dry-run (preview the effect without
/// writing) and a confirmed import. [batchId] identifies the write batch and is
/// what a later rollback targets. [preview] carries free-form per-row dicts the
/// backend produced while parsing — modeled as [ImportPreviewRow] so the UI can
/// render whatever columns the server sent without a fixed schema.
class ImportResult {
  const ImportResult({
    required this.batchId,
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.preview,
  });

  final String batchId;
  final int imported;
  final int updated;
  final int skipped;
  final List<ImportPreviewRow> preview;

  /// True when nothing would change (used to gate the confirm action).
  bool get isEmpty => imported == 0 && updated == 0 && skipped == 0;

  /// Total rows the server reported touching (created + updated + skipped).
  int get totalRows => imported + updated + skipped;

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
    final rawPreview = json['preview'];
    final rows = <ImportPreviewRow>[];
    if (rawPreview is List) {
      for (final item in rawPreview) {
        if (item is Map<String, dynamic>) {
          rows.add(ImportPreviewRow.fromJson(item));
        } else if (item is Map) {
          rows.add(ImportPreviewRow.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ));
        }
      }
    }
    return ImportResult(
      batchId: (json['batch_id'] ?? '').toString(),
      imported: asInt(json['imported']),
      updated: asInt(json['updated']),
      skipped: asInt(json['skipped']),
      preview: rows,
    );
  }
}

/// One free-form preview row from [ImportResult.preview].
///
/// The backend emits arbitrary key/value dicts here (the parsed CSV columns
/// plus any per-row note), so this is an order-preserving wrapper rather than a
/// typed record. The UI renders [values] in column order via [columns].
class ImportPreviewRow {
  const ImportPreviewRow(this.fields);

  /// Insertion-ordered map of column name → value (stringified for display).
  final Map<String, String> fields;

  /// Column names in their original order.
  List<String> get columns => fields.keys.toList();

  /// Display values aligned with [columns].
  List<String> get values => fields.values.toList();

  /// Common per-row status/note keys, if the backend included one.
  String? get note {
    for (final key in const ['note', 'message', 'reason', 'error', 'status']) {
      final v = fields[key];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  factory ImportPreviewRow.fromJson(Map<String, dynamic> json) {
    final fields = <String, String>{};
    json.forEach((key, value) {
      fields[key] = value == null ? '' : value.toString();
    });
    return ImportPreviewRow(fields);
  }
}

/// Status of an import batch as reported by the backend `status` column.
///
/// Mirrors the values written in
/// `backend/app/services/attendance.py` ("pending", "completed", "failed",
/// "rolled_back"); unknown strings fall back to [ImportStatus.unknown].
enum ImportStatus {
  pending,
  completed,
  failed,
  rolledBack,
  unknown;

  static ImportStatus fromCode(String? code) {
    switch (code) {
      case 'pending':
        return ImportStatus.pending;
      case 'completed':
      case 'success':
        return ImportStatus.completed;
      case 'failed':
        return ImportStatus.failed;
      case 'rolled_back':
        return ImportStatus.rolledBack;
      default:
        return ImportStatus.unknown;
    }
  }

  /// Korean user-facing label.
  String get label {
    switch (this) {
      case ImportStatus.pending:
        return '처리 중';
      case ImportStatus.completed:
        return '완료';
      case ImportStatus.failed:
        return '실패';
      case ImportStatus.rolledBack:
        return '롤백됨';
      case ImportStatus.unknown:
        return '알 수 없음';
    }
  }

  /// True when this batch can still be rolled back (has live records).
  bool get canRollback =>
      this == ImportStatus.completed || this == ImportStatus.pending;
}

/// One import-history entry (`GET /attendance/imports` → paginated list).
///
/// Source: `ImportLogOut` in `backend/app/schemas/attendance.py`.
class ImportLog {
  const ImportLog({
    required this.id,
    required this.batchId,
    required this.fileName,
    required this.cohortId,
    required this.rowCount,
    required this.successCount,
    required this.failCount,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String batchId;
  final String fileName;
  final int cohortId;
  final int rowCount;
  final int successCount;
  final int failCount;
  final ImportStatus status;
  final DateTime createdAt;

  factory ImportLog.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
    DateTime asDate(Object? v) =>
        v is String && v.isNotEmpty ? (DateTime.tryParse(v) ?? DateTime.now()) : DateTime.now();
    return ImportLog(
      id: asInt(json['id']),
      batchId: (json['batch_id'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      cohortId: asInt(json['cohort_id']),
      rowCount: asInt(json['row_count']),
      successCount: asInt(json['success_count']),
      failCount: asInt(json['fail_count']),
      status: ImportStatus.fromCode(json['status'] as String?),
      createdAt: asDate(json['created_at']),
    );
  }
}

/// A picked CSV file ready to upload (name + raw bytes).
///
/// Produced by the file-picker seam ([adminCsvPickerProvider]) or built from
/// pasted CSV text. Kept in the domain layer so both the provider and the
/// repository can refer to it without a UI dependency.
class CsvUpload {
  const CsvUpload({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;

  /// Builds an upload from pasted CSV [text] (UTF-8 encoded).
  factory CsvUpload.fromText(String text, {String fileName = 'attendance.csv'}) {
    return CsvUpload(
      fileName: fileName,
      bytes: utf8.encode(text),
    );
  }
}
