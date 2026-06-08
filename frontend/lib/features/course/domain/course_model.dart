/// Domain models for the course (수업/코스) + course-video feature.
///
/// These mirror the backend schemas in `app/schemas/course.py`
/// (`CourseOut`, `CourseVideoOut`). They hold NO business logic beyond the date
/// helpers — only field definitions, `fromJson`, and calendar-day expansion.
library;

import '../../../shared/utils/date_formatter.dart';

/// Parses a backend `YYYY-MM-DD` (DATE-only) string into a local-midnight
/// [DateTime] WITHOUT any timezone shift.
///
/// `DateTime.parse('2026-05-01')` already yields local midnight, but to be
/// fully safe against any stray time / timezone suffix we split on `-` and
/// build `DateTime(y, m, d)` directly. Returns null on malformed input.
DateTime? parseDateOnly(Object? raw) {
  final s = raw?.toString();
  if (s == null || s.isEmpty) return null;
  // Take just the date portion in case the backend ever appends a time.
  final datePart = s.split('T').first.split(' ').first;
  final parts = datePart.split('-');
  if (parts.length < 3) {
    // Fall back to the lenient parser, then normalize to date-only.
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Lifecycle status of a course (`courses.status`): active / archived.
enum CourseStatus {
  active,
  archived,
  unknown;

  static CourseStatus fromRaw(String? raw) {
    switch (raw) {
      case 'active':
        return CourseStatus.active;
      case 'archived':
        return CourseStatus.archived;
      default:
        return CourseStatus.unknown;
    }
  }

  /// Wire value sent back to the backend (`PATCH /courses/{id}`).
  String? get wire {
    switch (this) {
      case CourseStatus.active:
        return 'active';
      case CourseStatus.archived:
        return 'archived';
      case CourseStatus.unknown:
        return null;
    }
  }
}

/// A course (period-style 수업) as returned by `GET /courses/` and
/// `GET /courses/{id}` (`CourseOut`).
class Course {
  const Course({
    required this.id,
    required this.cohortId,
    required this.instructorId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    this.createdAt,
  });

  final int id;
  final int cohortId;
  final int instructorId;
  final String title;
  final String? description;

  /// DATE-only (local midnight). Period start, inclusive.
  final DateTime startDate;

  /// DATE-only (local midnight). Period end, inclusive.
  final DateTime endDate;

  final CourseStatus status;
  final DateTime? createdAt;

  /// Every calendar day from [startDate]..[endDate] INCLUSIVE
  /// (weekends/holidays included), using date-only arithmetic so a DST shift
  /// can never drop or duplicate a day.
  List<DateTime> dayList() {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) return [start];
    final days = <DateTime>[];
    var cursor = start;
    // Guard the loop to a sane upper bound (10 years) to avoid runaway loops on
    // bad data while still covering any realistic course period.
    var guard = 0;
    while (!cursor.isAfter(end) && guard < 3660) {
      days.add(cursor);
      final next = cursor.add(const Duration(days: 1));
      // Re-normalize to date-only to neutralize any DST hour drift.
      cursor = DateTime(next.year, next.month, next.day);
      guard++;
    }
    return days;
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    final desc = json['description']?.toString();
    return Course(
      id: asInt(json['id']) ?? 0,
      cohortId: asInt(json['cohort_id']) ?? 0,
      instructorId: asInt(json['instructor_id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (desc == null || desc.isEmpty) ? null : desc,
      startDate: parseDateOnly(json['start_date']) ?? DateTime.now(),
      endDate: parseDateOnly(json['end_date']) ?? DateTime.now(),
      status: CourseStatus.fromRaw(json['status']?.toString()),
      createdAt: DateFormatter.tryParse(json['created_at']?.toString()),
    );
  }
}

/// A single course video tied to a calendar day, as returned by
/// `POST /courses/{id}/videos` and `GET /courses/{id}/videos` (`CourseVideoOut`).
///
/// A day may carry MULTIPLE videos (no uniqueness constraint server-side).
class CourseVideo {
  const CourseVideo({
    required this.id,
    required this.courseId,
    required this.classDate,
    required this.fileKey,
    required this.uploadedBy,
    required this.sortOrder,
    this.title,
    this.originalFilename,
    this.contentType,
    this.sizeBytes,
    this.durationSeconds,
    this.createdAt,
  });

  final int id;
  final int courseId;

  /// DATE-only (local midnight): which day of the course this video belongs to.
  final DateTime classDate;

  final String? title;
  final String fileKey;
  final String? originalFilename;
  final String? contentType;
  final int? sizeBytes;
  final int? durationSeconds;
  final int sortOrder;
  final int uploadedBy;
  final DateTime? createdAt;

  /// Best label for the video: explicit [title], else [originalFilename], else
  /// a generic fallback.
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    if (originalFilename != null && originalFilename!.trim().isNotEmpty) {
      return originalFilename!.trim();
    }
    return '영상 #$id';
  }

  factory CourseVideo.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    String? str(Object? v) {
      final s = v?.toString();
      return (s == null || s.isEmpty) ? null : s;
    }

    return CourseVideo(
      id: asInt(json['id']) ?? 0,
      courseId: asInt(json['course_id']) ?? 0,
      classDate: parseDateOnly(json['class_date']) ?? DateTime.now(),
      title: str(json['title']),
      fileKey: (json['file_key'] ?? '').toString(),
      originalFilename: str(json['original_filename']),
      contentType: str(json['content_type']),
      sizeBytes: asInt(json['size_bytes']),
      durationSeconds: asInt(json['duration_seconds']),
      sortOrder: asInt(json['sort_order']) ?? 0,
      uploadedBy: asInt(json['uploaded_by']) ?? 0,
      createdAt: DateFormatter.tryParse(json['created_at']?.toString()),
    );
  }
}

/// A per-day class log (수업일지) for one calendar day of a course, as returned
/// by `GET /courses/{id}/day-logs`, `GET /courses/{id}/day-logs/{class_date}`,
/// and `PUT /courses/{id}/day-logs` (upsert).
///
/// At most one log exists per (course, [classDate]).
class CourseDayLog {
  const CourseDayLog({
    required this.id,
    required this.courseId,
    required this.classDate,
    required this.content,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int courseId;

  /// DATE-only (local midnight): which day of the course this log belongs to.
  final DateTime classDate;

  final String content;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when the log carries any non-whitespace content.
  bool get hasContent => content.trim().isNotEmpty;

  factory CourseDayLog.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return CourseDayLog(
      id: asInt(json['id']) ?? 0,
      courseId: asInt(json['course_id']) ?? 0,
      classDate: parseDateOnly(json['class_date']) ?? DateTime.now(),
      content: (json['content'] ?? '').toString(),
      updatedBy: asInt(json['updated_by']),
      createdAt: DateFormatter.tryParse(json['created_at']?.toString()),
      updatedAt: DateFormatter.tryParse(json['updated_at']?.toString()),
    );
  }
}
