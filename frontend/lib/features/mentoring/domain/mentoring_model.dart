/// Domain models for the instructor mentoring / counseling feature.
///
/// Shapes mirror the backend Pydantic schemas in
/// `backend/app/schemas/class_.py`:
///   - [MentoringLog]    ← `MentoringLogOut`
///   - [ClassEvaluation] ← `EvaluationSummary`
///   - [CohortStudent]   ← an item of the `/users` list payload (`UserListItem`)
///
/// These are pure data holders: no API calls, no business logic.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

/// A single mentoring / counseling session record written by an instructor for
/// a student. Mirrors `MentoringLogOut`.
class MentoringLog {
  const MentoringLog({
    required this.id,
    required this.cohortId,
    required this.instructorId,
    required this.studentId,
    required this.sessionDate,
    required this.content,
    this.followUp,
    this.createdAt,
  });

  final int id;
  final int cohortId;
  final int instructorId;
  final int studentId;

  /// Date the counseling session took place (date-only on the server).
  final DateTime sessionDate;

  /// Free-text counseling notes.
  final String content;

  /// Optional follow-up plan / action items.
  final String? followUp;

  final DateTime? createdAt;

  bool get hasFollowUp => (followUp ?? '').trim().isNotEmpty;

  factory MentoringLog.fromJson(Map<String, dynamic> json) {
    return MentoringLog(
      id: _asInt(json['id']) ?? 0,
      cohortId: _asInt(json['cohort_id']) ?? 0,
      instructorId: _asInt(json['instructor_id']) ?? 0,
      studentId: _asInt(json['student_id']) ?? 0,
      sessionDate:
          DateTime.tryParse((json['session_date'] ?? '').toString()) ??
              DateTime.now(),
      content: (json['content'] ?? '').toString(),
      followUp: json['follow_up']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

/// A student belonging to a cohort, used only to pick the counseling subject
/// when composing a mentoring log. Mirrors `UserListItem`.
class CohortStudent {
  const CohortStudent({
    required this.id,
    required this.name,
    required this.email,
    this.cohortId,
  });

  final int id;
  final String name;
  final String email;
  final int? cohortId;

  factory CohortStudent.fromJson(Map<String, dynamic> json) {
    return CohortStudent(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      cohortId: _asInt(json['cohort_id']),
    );
  }
}

/// Aggregated, fully anonymised course-evaluation results for a single class.
///
/// Mirrors `EvaluationSummary`. The backend never returns the submitting
/// student's identity here — only an [average], a total [count], a star
/// [distribution] (key "1".."5" → number of votes) and a flat list of free-text
/// [comments] with NO author attached. The UI MUST keep it that way.
class ClassEvaluation {
  const ClassEvaluation({
    required this.average,
    required this.count,
    required this.distribution,
    required this.comments,
  });

  /// Mean rating (0.0 when there are no submissions).
  final double average;

  /// Total number of submissions.
  final int count;

  /// Star value (1–5) → number of votes.
  final Map<int, int> distribution;

  /// Anonymous free-text comments (no author identity attached).
  final List<String> comments;

  bool get isEmpty => count == 0;

  /// Votes for [star] (1–5), defaulting to 0.
  int votesFor(int star) => distribution[star] ?? 0;

  /// Fraction (0.0–1.0) of votes for [star], used to size distribution bars.
  double ratioFor(int star) => count == 0 ? 0 : votesFor(star) / count;

  factory ClassEvaluation.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribution'];
    final dist = <int, int>{};
    if (rawDist is Map) {
      rawDist.forEach((k, v) {
        final star = int.tryParse(k.toString());
        final votes = _asInt(v);
        if (star != null && votes != null) dist[star] = votes;
      });
    }

    final rawComments = json['comments'];
    final comments = <String>[];
    if (rawComments is List) {
      for (final c in rawComments) {
        if (c != null) comments.add(c.toString());
      }
    }

    final rawAvg = json['average'];
    return ClassEvaluation(
      average: rawAvg is num ? rawAvg.toDouble() : 0.0,
      count: _asInt(json['count']) ?? 0,
      distribution: dist,
      comments: comments,
    );
  }
}
