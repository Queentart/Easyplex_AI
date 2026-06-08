import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// A selectable cohort option for the global nav cohort filter.
class CohortOption {
  const CohortOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// The globally-selected cohort used as the DEFAULT (1st-level) filter for
/// cohort-scoped screens (attendance, assignments, boards, inquiries, …).
///
/// `null` means "기수 전체" (all cohorts) — the default. The nav header dropdown
/// (instructor / operations) drives this; screens watch it and apply it as
/// their initial cohort filter, while still offering their own in-screen
/// (2nd-level) filters for cross-cohort inspection.
class SelectedCohortNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = 기수 전체

  void select(int? cohortId) => state = cohortId;
}

final selectedCohortProvider =
    NotifierProvider<SelectedCohortNotifier, int?>(SelectedCohortNotifier.new);

/// Cohort options for the nav dropdown. `GET /cohorts/` is callable by any
/// authenticated user; the backend scopes the result by role (operations sees
/// all institution cohorts; an instructor sees their assigned cohorts).
final cohortOptionsProvider = FutureProvider<List<CohortOption>>((ref) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/cohorts/');
  final data = res.data?['data'];
  if (data is! List) return const <CohortOption>[];
  return data
      .whereType<Map<String, dynamic>>()
      .map((j) => CohortOption(
            id: (j['id'] as num).toInt(),
            name: (j['name'] ?? '기수 ${j['id']}').toString(),
          ))
      .toList();
});
