/// Domain models for the instructor class-management feature.
///
/// These mirror the backend schemas in `backend/app/schemas/class_.py`
/// (`ClassOut`, `TrainingLogOut`, `CurriculumItemOut`, `CareerPostingOut`) and
/// the `ClassRecording` row created by `add_recording`. They hold NO business
/// logic — only JSON (de)serialization plus small presentation-friendly
/// accessors.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
bool _asBool(Object? v) => v is bool ? v : false;
String _asString(Object? v) => v?.toString() ?? '';

DateTime? _asDateTime(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// Parses a backend `date` (`YYYY-MM-DD`) into a [DateTime] at local midnight.
DateTime? _asDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// Parses a backend `time` (`HH:MM[:SS]`) into a display string `HH:MM`.
String _asTime(Object? v) {
  final raw = _asString(v);
  if (raw.isEmpty) return '';
  final parts = raw.split(':');
  if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
  return raw;
}

/// A class material descriptor stored on a class as a free-form `list[dict]`.
///
/// The backend keeps `materials` untyped; this feature uses the
/// `{title, file_key, url}` shape. Missing keys are tolerated.
class ClassMaterial {
  const ClassMaterial({this.title, this.fileKey, this.url});

  final String? title;
  final String? fileKey;
  final String? url;

  /// A user-facing label for the material chip.
  String get label =>
      (title != null && title!.isNotEmpty) ? title! : (fileKey ?? url ?? '자료');

  factory ClassMaterial.fromJson(Map<String, dynamic> json) {
    return ClassMaterial(
      title: json['title']?.toString(),
      fileKey: json['file_key']?.toString(),
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (fileKey != null) 'file_key': fileKey,
        if (url != null) 'url': url,
      };
}

/// A scheduled class session (`ClassOut`).
///
/// `status` is a free-form string from the server: `scheduled`, `ongoing`,
/// `completed`, `cancelled`.
class ClassSession {
  const ClassSession({
    required this.id,
    required this.cohortId,
    required this.instructorId,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.materials,
    required this.createdAt,
    this.location,
  });

  final int id;
  final int cohortId;
  final int instructorId;
  final String title;

  /// Class day (local midnight).
  final DateTime date;

  /// `HH:MM` display strings.
  final String startTime;
  final String endTime;

  final String? location;
  final String status;
  final List<ClassMaterial> materials;
  final DateTime createdAt;

  /// `09:00 ~ 12:00` range label.
  String get timeRange =>
      [startTime, endTime].where((s) => s.isNotEmpty).join(' ~ ');

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// True when [viewerId] is the assigned instructor — gates training-log /
  /// recording / edit actions client-side (server enforces too).
  bool isOwnedBy(int? viewerId) =>
      viewerId != null && viewerId == instructorId;

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    final rawMaterials = json['materials'];
    return ClassSession(
      id: _asInt(json['id']) ?? 0,
      cohortId: _asInt(json['cohort_id']) ?? 0,
      instructorId: _asInt(json['instructor_id']) ?? 0,
      title: _asString(json['title']),
      date: _asDate(json['date']) ?? DateTime.now(),
      startTime: _asTime(json['start_time']),
      endTime: _asTime(json['end_time']),
      location: json['location']?.toString(),
      status: _asString(json['status']).isEmpty
          ? 'scheduled'
          : _asString(json['status']),
      materials: rawMaterials is List
          ? rawMaterials
              .whereType<Map>()
              .map((e) => ClassMaterial.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList()
          : const [],
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// A class recording. The backend stores the file key in `recording_url`; the
/// presentation layer exposes it as a watch link.
class ClassRecording {
  const ClassRecording({
    required this.fileKey,
    this.title,
    this.durationSeconds,
  });

  /// S3 file key (sent as `file_key` on create; returned as `recording_url`).
  final String fileKey;
  final String? title;
  final int? durationSeconds;

  /// `1시간 23분` style duration label, or null when unknown.
  String? get durationLabel {
    final s = durationSeconds;
    if (s == null || s <= 0) return null;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  factory ClassRecording.fromJson(Map<String, dynamic> json) {
    return ClassRecording(
      fileKey:
          _asString(json['recording_url']).isEmpty
              ? _asString(json['file_key'])
              : _asString(json['recording_url']),
      title: json['title']?.toString(),
      durationSeconds: _asInt(json['duration_seconds']),
    );
  }
}

/// A training log for a class (`TrainingLogOut`).
///
/// Editing is restricted server-side to 24h after [submittedAt] for
/// instructors; [editDeadline] / [isEditable] surface that limit in the UI.
class TrainingLog {
  const TrainingLog({
    required this.id,
    required this.classId,
    required this.instructorId,
    required this.content,
    required this.submittedAt,
    required this.createdAt,
    this.achievements,
    this.nextPlan,
    this.attendanceSummary,
  });

  final int id;
  final int classId;
  final int instructorId;
  final String content;
  final String? achievements;
  final String? nextPlan;
  final Map<String, dynamic>? attendanceSummary;
  final DateTime submittedAt;
  final DateTime createdAt;

  /// The 24h instructor edit deadline (server-enforced).
  DateTime get editDeadline => submittedAt.add(const Duration(hours: 24));

  /// True while still inside the 24h window (instructor view).
  bool get isEditable => DateTime.now().isBefore(editDeadline);

  /// Remaining edit window, or [Duration.zero] once it has closed.
  Duration get remainingEditWindow {
    final diff = editDeadline.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory TrainingLog.fromJson(Map<String, dynamic> json) {
    final summary = json['attendance_summary'];
    return TrainingLog(
      id: _asInt(json['id']) ?? 0,
      classId: _asInt(json['class_id']) ?? 0,
      instructorId: _asInt(json['instructor_id']) ?? 0,
      content: _asString(json['content']),
      achievements: json['achievements']?.toString(),
      nextPlan: json['next_plan']?.toString(),
      attendanceSummary: summary is Map
          ? summary.map((k, v) => MapEntry(k.toString(), v))
          : null,
      submittedAt: _asDateTime(json['submitted_at']) ?? DateTime.now(),
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// A curriculum item (`CurriculumItemOut`).
///
/// Items form a tree via [parentItemId]; the curriculum screen groups by [week]
/// and nests children under their parent. Progress is derived from
/// [isCompleted] across leaf items.
class CurriculumItem {
  const CurriculumItem({
    required this.id,
    required this.cohortId,
    required this.week,
    required this.topic,
    required this.isCompleted,
    required this.sortOrder,
    required this.createdAt,
    this.day,
    this.description,
    this.plannedHours,
    this.actualHours,
    this.completedAt,
    this.parentItemId,
  });

  final int id;
  final int cohortId;
  final int week;
  final int? day;
  final String topic;
  final String? description;
  final int? plannedHours;
  final int? actualHours;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? parentItemId;
  final int sortOrder;
  final DateTime createdAt;

  bool get isRoot => parentItemId == null;

  factory CurriculumItem.fromJson(Map<String, dynamic> json) {
    return CurriculumItem(
      id: _asInt(json['id']) ?? 0,
      cohortId: _asInt(json['cohort_id']) ?? 0,
      week: _asInt(json['week']) ?? 0,
      day: _asInt(json['day']),
      topic: _asString(json['topic']),
      description: json['description']?.toString(),
      plannedHours: _asInt(json['planned_hours']),
      actualHours: _asInt(json['actual_hours']),
      isCompleted: _asBool(json['is_completed']),
      completedAt: _asDateTime(json['completed_at']),
      parentItemId: _asInt(json['parent_item_id']),
      sortOrder: _asInt(json['sort_order']) ?? 0,
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// The outcome of a student submitting a course evaluation
/// (`POST /classes/{id}/evaluations`).
///
/// The backend returns `{"ok": true}` on success; this model captures that
/// acknowledgement. Evaluations are anonymous to the instructor — the student
/// identity is never returned here nor surfaced anywhere in the UI.
class EvaluationResult {
  const EvaluationResult({required this.ok});

  final bool ok;

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(ok: _asBool(json['ok']));
  }
}

/// A career / job posting, certification, or special-lecture notice
/// (`CareerPostingOut`).
///
/// `postingType` is a free-form string from the server: `job`, `certification`,
/// `special_lecture`, etc.
class CareerPosting {
  const CareerPosting({
    required this.id,
    required this.institutionId,
    required this.postingType,
    required this.title,
    required this.content,
    required this.createdBy,
    required this.createdAt,
    this.externalUrl,
    this.startDate,
    this.endDate,
    this.targetCohortIds = const [],
  });

  final int id;
  final int institutionId;
  final String postingType;
  final String title;
  final String content;
  final String? externalUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int> targetCohortIds;
  final int createdBy;
  final DateTime createdAt;

  factory CareerPosting.fromJson(Map<String, dynamic> json) {
    final raw = json['target_cohort_ids'];
    return CareerPosting(
      id: _asInt(json['id']) ?? 0,
      institutionId: _asInt(json['institution_id']) ?? 0,
      postingType: _asString(json['posting_type']).isEmpty
          ? 'job'
          : _asString(json['posting_type']),
      title: _asString(json['title']),
      content: _asString(json['content']),
      externalUrl: json['external_url']?.toString(),
      startDate: _asDate(json['start_date']),
      endDate: _asDate(json['end_date']),
      targetCohortIds: raw is List
          ? raw.map(_asInt).whereType<int>().toList()
          : const [],
      createdBy: _asInt(json['created_by']) ?? 0,
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}
