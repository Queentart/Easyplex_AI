/// In-screen (2nd-level) cohort filter for the inquiry/ticket list.
///
/// The backend `GET /inquiries/` does NOT accept a `cohort_id` query param, but
/// every `InquiryOut` carries `cohort_id`, so the operator-facing list filters
/// CLIENT-SIDE over the already-loaded page. This spec parses an operator's
/// free-form cohort expression and decides whether a given cohort id matches.
///
/// Supported expression grammar (comma-separated tokens, whitespace ignored):
///   - `3`        → exactly cohort 3
///   - `1,2,5`    → cohorts 1, 2 or 5
///   - `5-7`      → cohorts 5 through 7 (inclusive)
///   - `5+`       → cohort 5 and every later cohort ("특정 기수 이후")
///   - `` (empty) → no cohort constraint (everything the role can see)
///
/// This holds NO business logic beyond parsing/matching — it is a pure value
/// object so the provider and the UI can share it.
library;

/// A parsed cohort-filter expression. Construct via [CohortFilterSpec.parse];
/// [CohortFilterSpec.none] matches everything.
class CohortFilterSpec {
  const CohortFilterSpec._({
    required this.ids,
    required this.ranges,
    required this.atLeast,
    required this.raw,
    required this.invalidTokens,
  });

  /// The empty spec — matches every cohort (and the "no cohort" case).
  static const CohortFilterSpec none = CohortFilterSpec._(
    ids: <int>{},
    ranges: <(int, int)>[],
    atLeast: null,
    raw: '',
    invalidTokens: <String>[],
  );

  /// Exact cohort ids (`3`, `1,2,5`).
  final Set<int> ids;

  /// Inclusive ranges (`5-7` → (5, 7)).
  final List<(int, int)> ranges;

  /// Lower bound for an open-ended "이 기수 이후" token (`5+` → 5). When set,
  /// any cohort id `>= atLeast` matches.
  final int? atLeast;

  /// The original text the operator typed (echoed back into the field).
  final String raw;

  /// Tokens that could not be parsed (surfaced as a hint, never silently
  /// dropped so the operator knows the filter is partially ignored).
  final List<String> invalidTokens;

  /// True when this spec imposes no constraint.
  bool get isEmpty => ids.isEmpty && ranges.isEmpty && atLeast == null;

  bool get hasErrors => invalidTokens.isNotEmpty;

  /// Whether a cohort [id] passes the filter. A `null` id (inquiry with no
  /// cohort) only passes the empty spec.
  bool matches(int? id) {
    if (isEmpty) return true;
    if (id == null) return false;
    if (ids.contains(id)) return true;
    if (atLeast != null && id >= atLeast!) return true;
    for (final (lo, hi) in ranges) {
      if (id >= lo && id <= hi) return true;
    }
    return false;
  }

  /// Builds a single-cohort spec, used to pre-fill from the global
  /// [selectedCohortProvider]. A `null` cohort yields [none].
  factory CohortFilterSpec.single(int? cohortId) {
    if (cohortId == null) return none;
    return CohortFilterSpec._(
      ids: {cohortId},
      ranges: const [],
      atLeast: null,
      raw: '$cohortId',
      invalidTokens: const [],
    );
  }

  /// Parses an operator expression (see the grammar in the library doc).
  factory CohortFilterSpec.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return none;

    final ids = <int>{};
    final ranges = <(int, int)>[];
    int? atLeast;
    final invalid = <String>[];

    for (final rawToken in trimmed.split(',')) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;

      // Open-ended "N+".
      if (token.endsWith('+')) {
        final n = int.tryParse(token.substring(0, token.length - 1).trim());
        if (n == null || n < 0) {
          invalid.add(token);
        } else {
          atLeast = atLeast == null ? n : (n < atLeast ? n : atLeast);
        }
        continue;
      }

      // Range "A-B".
      if (token.contains('-')) {
        final parts = token.split('-');
        if (parts.length != 2) {
          invalid.add(token);
          continue;
        }
        final lo = int.tryParse(parts[0].trim());
        final hi = int.tryParse(parts[1].trim());
        if (lo == null || hi == null || lo < 0 || hi < lo) {
          invalid.add(token);
        } else {
          ranges.add((lo, hi));
        }
        continue;
      }

      // Single id.
      final n = int.tryParse(token);
      if (n == null || n < 0) {
        invalid.add(token);
      } else {
        ids.add(n);
      }
    }

    return CohortFilterSpec._(
      ids: ids,
      ranges: ranges,
      atLeast: atLeast,
      raw: trimmed,
      invalidTokens: invalid,
    );
  }

  /// A short Korean summary of the active constraint, for chips/labels.
  ///
  /// NOTE: the Korean suffix `기` is concatenated as a separate literal rather
  /// than interpolated (e.g. `'$id기'`) because a trailing Hangul glyph is a
  /// valid Dart identifier-continuation char, so `$id기` would resolve to a
  /// (nonexistent) `id기` identifier. Using `'$id' + gi` keeps it correct and
  /// avoids the (false-positive) "unnecessary braces" lint on `'${id}기'`.
  String get summary {
    if (isEmpty) return '전체 기수';
    const gi = '기';
    final parts = <String>[];
    final sortedIds = ids.toList()..sort();
    for (final id in sortedIds) {
      parts.add('$id$gi');
    }
    for (final (lo, hi) in ranges) {
      parts.add('$lo-$hi$gi');
    }
    if (atLeast != null) parts.add('$atLeast$gi 이후');
    return parts.join(', ');
  }
}
