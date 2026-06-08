/// Domain models for the early-leave / sick-leave (조퇴·병결) feature.
///
/// Pure Dart data classes with `fromJson` / `toJson` only — no business logic,
/// no API calls. Mirrors the backend `LeaveRequestOut` / `LeaveRequestCreate`
/// schemas (see backend `app/schemas/leave.py`).
library;

/// Leave-request type. Backend stores the raw string in `leave_requests.type`.
///   - early_leave : 조퇴
///   - medical     : 병결
///   - official    : 공결 (공식 인정 결석)
enum LeaveType {
  earlyLeave('early_leave', '조퇴'),
  medical('medical', '병결'),
  official('official', '공결');

  const LeaveType(this.code, this.label);

  /// Wire value sent to / received from the backend.
  final String code;

  /// Korean UI label.
  final String label;

  static LeaveType fromCode(String? code) {
    return LeaveType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => LeaveType.earlyLeave,
    );
  }
}

/// Leave-request status. Backend stores the raw string in `leave_requests.status`.
enum LeaveStatus {
  pending('pending', '대기'),
  approved('approved', '승인'),
  rejected('rejected', '반려'),
  canceled('canceled', '취소');

  const LeaveStatus(this.code, this.label);

  final String code;
  final String label;

  static LeaveStatus fromCode(String? code) {
    return LeaveStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => LeaveStatus.pending,
    );
  }
}

/// A single early-leave / sick-leave request.
///
/// Maps the backend `LeaveRequestOut` envelope `data` object.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.cohortId,
    required this.studentId,
    required this.type,
    required this.targetDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.startTime,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComment,
  });

  final int id;
  final int cohortId;
  final int studentId;
  final LeaveType type;

  /// The day the leave applies to (date-only; time component is ignored).
  final DateTime targetDate;

  /// For [LeaveType.earlyLeave]: the time the student leaves. `"HH:mm"` or
  /// `"HH:mm:ss"` as returned by the backend `time` field. Null otherwise.
  final String? startTime;

  final String reason;
  final LeaveStatus status;

  /// Reviewer (operations-team) user id once processed; null while pending.
  final int? reviewedBy;
  final DateTime? reviewedAt;

  /// Operations-team comment attached on approve / reject.
  final String? reviewComment;

  final DateTime createdAt;

  /// True while the request can still be canceled by the student.
  bool get isPending => status == LeaveStatus.pending;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

    DateTime? asDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return LeaveRequest(
      id: asInt(json['id']) ?? 0,
      cohortId: asInt(json['cohort_id']) ?? 0,
      studentId: asInt(json['student_id']) ?? 0,
      type: LeaveType.fromCode(json['type']?.toString()),
      targetDate: asDate(json['target_date']) ?? DateTime.now(),
      startTime: json['start_time']?.toString(),
      reason: (json['reason'] ?? '').toString(),
      status: LeaveStatus.fromCode(json['status']?.toString()),
      reviewedBy: asInt(json['reviewed_by']),
      reviewedAt: asDate(json['reviewed_at']),
      reviewComment: json['review_comment']?.toString(),
      createdAt: asDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// Payload for `POST /leave-requests`, mirroring backend `LeaveRequestCreate`.
///
/// `targetDate` is serialised as `YYYY-MM-DD` and `startTime` as `HH:mm`
/// (both date/time-only, matching the backend `date` / `time` columns).
class LeaveRequestCreate {
  const LeaveRequestCreate({
    required this.type,
    required this.targetDate,
    required this.reason,
    this.startTime,
    this.evidence,
  });

  final LeaveType type;
  final DateTime targetDate;
  final String reason;

  /// Only meaningful for [LeaveType.earlyLeave].
  final TimeOfDayValue? startTime;

  /// Optional uploaded supporting document (after the presign + PUT flow).
  final UploadedFile? evidence;

  Map<String, dynamic> toJson() {
    final y = targetDate.year.toString().padLeft(4, '0');
    final m = targetDate.month.toString().padLeft(2, '0');
    final d = targetDate.day.toString().padLeft(2, '0');

    return {
      'type': type.code,
      'target_date': '$y-$m-$d',
      if (startTime != null) 'start_time': startTime!.toWire(),
      'reason': reason,
      if (evidence != null) ...{
        'evidence_key': evidence!.fileKey,
        'evidence_name': evidence!.fileName,
        'evidence_size': evidence!.fileSize,
      },
    };
  }
}

/// Prefill values for the create form, decoded from go_router query params.
///
/// Used when navigating to `/student/leave-requests/new` from another screen
/// (e.g. the attendance exceptions list) to pre-populate the form. Encoded as
/// query parameters — NOT `extra` — so a hard web reload of the URL still
/// reconstructs the same prefilled state. All fields are optional; an absent or
/// unparsable value simply leaves that field at its form default.
class LeaveFormPrefill {
  const LeaveFormPrefill({this.type, this.targetDate, this.startTime});

  final LeaveType? type;
  final DateTime? targetDate;
  final TimeOfDayValue? startTime;

  bool get isEmpty => type == null && targetDate == null && startTime == null;

  /// Decodes `?type=early_leave&date=2026-05-12&start_time=14:30` (any subset).
  ///   - `type`       : a [LeaveType] code (`early_leave` / `medical` / `official`)
  ///   - `date`       : `YYYY-MM-DD`
  ///   - `start_time` : `HH:mm`
  factory LeaveFormPrefill.fromQuery(Map<String, String> query) {
    final typeCode = query['type'];
    final type = (typeCode != null && typeCode.isNotEmpty)
        ? LeaveType.values
            .where((t) => t.code == typeCode)
            .cast<LeaveType?>()
            .firstWhere((_) => true, orElse: () => null)
        : null;

    DateTime? date;
    final rawDate = query['date'];
    if (rawDate != null && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate);
    }

    TimeOfDayValue? time;
    final rawTime = query['start_time'];
    if (rawTime != null && rawTime.contains(':')) {
      final parts = rawTime.split(':');
      final h = int.tryParse(parts[0]);
      final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (h != null && m != null) time = TimeOfDayValue(h, m);
    }

    return LeaveFormPrefill(type: type, targetDate: date, startTime: time);
  }

  /// Builds the query-parameter map for navigating to the create form.
  /// Only non-null fields are included.
  static Map<String, String> toQuery({
    LeaveType? type,
    DateTime? targetDate,
    TimeOfDayValue? startTime,
  }) {
    final q = <String, String>{};
    if (type != null) q['type'] = type.code;
    if (targetDate != null) {
      final y = targetDate.year.toString().padLeft(4, '0');
      final m = targetDate.month.toString().padLeft(2, '0');
      final d = targetDate.day.toString().padLeft(2, '0');
      q['date'] = '$y-$m-$d';
    }
    if (startTime != null) q['start_time'] = startTime.toWire();
    return q;
  }
}

/// Lightweight, framework-free time value (avoids importing Flutter into the
/// domain layer). Serialises to `HH:mm` for the backend `time` column.
class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);

  final int hour;
  final int minute;

  String toWire() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get label => toWire();
}

/// The current user's leave allowance / usage summary.
///
/// Mirrors the backend `GET /leave-requests/balance` `data` object. When the
/// cohort has no allowance configured, [hasAllowance] is false and both
/// [allowanceDays] and [remainingDays] are null (기수 한도 미설정).
class LeaveBalance {
  const LeaveBalance({
    required this.usedDays,
    required this.hasAllowance,
    this.allowanceDays,
    this.remainingDays,
  });

  /// Total allowed leave days for the cohort, or null when 미설정.
  final int? allowanceDays;

  /// Leave days already consumed (approved requests).
  final int usedDays;

  /// Remaining leave days, or null when the allowance is 미설정.
  final int? remainingDays;

  /// True when the cohort has a configured allowance.
  final bool hasAllowance;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    bool asBool(Object? v) => v is bool ? v : v == true || v == 'true';

    return LeaveBalance(
      allowanceDays: asInt(json['allowance_days']),
      usedDays: asInt(json['used_days']) ?? 0,
      remainingDays: asInt(json['remaining_days']),
      hasAllowance: asBool(json['has_allowance']),
    );
  }
}

/// A supporting document successfully uploaded to object storage via the
/// `/files/presign` → S3 `PUT` flow. The [fileKey] is what the create payload
/// references; the backend resolves it server-side.
class UploadedFile {
  const UploadedFile({
    required this.fileKey,
    required this.fileName,
    required this.fileSize,
  });

  final String fileKey;
  final String fileName;
  final int fileSize;
}
