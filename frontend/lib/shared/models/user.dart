/// Current logged-in user, as returned in the `user` object of `/auth/login`
/// and by `/auth/me`.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.cohortId,
    this.cohortIds = const [],
    this.institutionId,
  });

  final int id;
  final String email;
  final String name;
  final String role;

  /// The single cohort id (set for students only). NULL for instructors, who
  /// are linked to cohorts via the many-to-many join — see [cohortIds].
  final int? cohortId;

  /// Every cohort this user is associated with: a student's single cohort, or
  /// an instructor's full set of taught cohorts (from `instructor_cohorts`).
  final List<int> cohortIds;

  final int? institutionId;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    List<int> asIntList(Object? v) {
      if (v is! List) return const [];
      return v.map(asInt).whereType<int>().toList();
    }

    return AppUser(
      id: asInt(json['id']) ?? 0,
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      cohortId: asInt(json['cohort_id']),
      cohortIds: asIntList(json['cohort_ids']),
      institutionId: asInt(json['institution_id']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'cohort_id': cohortId,
        'cohort_ids': cohortIds,
        'institution_id': institutionId,
      };

  AppUser copyWith({
    int? id,
    String? email,
    String? name,
    String? role,
    int? cohortId,
    List<int>? cohortIds,
    int? institutionId,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      cohortId: cohortId ?? this.cohortId,
      cohortIds: cohortIds ?? this.cohortIds,
      institutionId: institutionId ?? this.institutionId,
    );
  }
}
