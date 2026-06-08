/// Domain models for the student assignment feature.
///
/// These mirror the backend schemas in `app/schemas/assignment.py`
/// (`AssignmentOut`, `SubmissionOut`). They hold NO business logic — only
/// field definitions and `fromJson` / request-shaping helpers.
library;

import '../../../shared/utils/date_formatter.dart';

/// Lifecycle status of an assignment, as stored in `assignments.status`.
/// Values: open / closed / archived (see backend model comment).
enum AssignmentStatus {
  open,
  closed,
  archived,
  unknown;

  static AssignmentStatus fromRaw(String? raw) {
    switch (raw) {
      case 'open':
        return AssignmentStatus.open;
      case 'closed':
        return AssignmentStatus.closed;
      case 'archived':
        return AssignmentStatus.archived;
      default:
        return AssignmentStatus.unknown;
    }
  }
}

/// Status of a single student's submission (`submissions.status`).
/// Values: submitted / reviewed / resubmit_requested.
enum SubmissionStatus {
  submitted,
  reviewed,
  resubmitRequested,
  unknown;

  static SubmissionStatus fromRaw(String? raw) {
    switch (raw) {
      case 'submitted':
        return SubmissionStatus.submitted;
      case 'reviewed':
        return SubmissionStatus.reviewed;
      case 'resubmit_requested':
        return SubmissionStatus.resubmitRequested;
      default:
        return SubmissionStatus.unknown;
    }
  }
}

/// An assignment as returned by `GET /assignments` and
/// `GET /assignments/{id}` (`AssignmentOut`).
class Assignment {
  const Assignment({
    required this.id,
    required this.cohortId,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.allowLateSubmission,
    required this.status,
    this.maxScore,
    this.createdAt,
  });

  final int id;
  final int cohortId;
  final int createdBy;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool allowLateSubmission;
  final int? maxScore;
  final AssignmentStatus status;
  final DateTime? createdAt;

  /// True once the due date has passed (relative to [now], default: now).
  bool isOverdue({DateTime? now}) =>
      (now ?? DateTime.now()).isAfter(dueDate.toLocal());

  /// Submission is still possible: assignment open AND (not overdue OR late
  /// submission allowed). The server is the final authority — this only drives
  /// the UI affordance.
  bool canSubmit({DateTime? now}) {
    if (status != AssignmentStatus.open) return false;
    if (isOverdue(now: now)) return allowLateSubmission;
    return true;
  }

  /// Remaining time until the due date, negative once overdue.
  Duration remaining({DateTime? now}) =>
      dueDate.toLocal().difference(now ?? DateTime.now());

  factory Assignment.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return Assignment(
      id: asInt(json['id']) ?? 0,
      cohortId: asInt(json['cohort_id']) ?? 0,
      createdBy: asInt(json['created_by']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      dueDate: DateFormatter.tryParse(json['due_date']?.toString()) ??
          DateTime.now(),
      allowLateSubmission: json['allow_late_submission'] == true,
      maxScore: asInt(json['max_score']),
      status: AssignmentStatus.fromRaw(json['status']?.toString()),
      createdAt: DateFormatter.tryParse(json['created_at']?.toString()),
    );
  }
}

/// The current student's OWN submission, as returned by
/// `POST /assignments/{id}/submissions` and `GET /submissions/{id}`
/// (`SubmissionOut`).
///
/// IMPORTANT: this only ever represents the signed-in student's own work. The
/// backend RBAC + RLS guarantees a student can never read another student's
/// submission, and the UI never requests or renders one.
class Submission {
  const Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.submittedAt,
    required this.isLate,
    required this.status,
    this.content,
    this.score,
    this.createdAt,
  });

  final int id;
  final int assignmentId;
  final int studentId;
  final String? content;
  final DateTime submittedAt;
  final bool isLate;
  final int? score;
  final SubmissionStatus status;
  final DateTime? createdAt;

  factory Submission.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return Submission(
      id: asInt(json['id']) ?? 0,
      assignmentId: asInt(json['assignment_id']) ?? 0,
      studentId: asInt(json['student_id']) ?? 0,
      content: json['content']?.toString(),
      submittedAt: DateFormatter.tryParse(json['submitted_at']?.toString()) ??
          DateTime.now(),
      isLate: json['is_late'] == true,
      score: asInt(json['score']),
      status: SubmissionStatus.fromRaw(json['status']?.toString()),
      createdAt: DateFormatter.tryParse(json['created_at']?.toString()),
    );
  }
}

/// A file staged for upload / attached to a submission.
///
/// The backend `SubmissionCreate` accepts a SINGLE file per call
/// (`file_key/file_name/file_size/mime_type`); see the repository for how
/// multiple staged files are uploaded across repeated submission calls.
class SubmissionFileRef {
  const SubmissionFileRef({
    required this.fileKey,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
  });

  final String fileKey;
  final String fileName;
  final int fileSize;
  final String? mimeType;

  Map<String, dynamic> toJson() => {
        'file_key': fileKey,
        'file_name': fileName,
        'file_size': fileSize,
        if (mimeType != null) 'mime_type': mimeType,
      };
}
