import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/file_pick.dart' as file_pick;
import '../data/admin_repository.dart';
import '../domain/admin_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// User management
/// ─────────────────────────────────────────────────────────────────────────

/// SERVER-SIDE filter arguments for the user list (drives the `GET /users/`
/// query). Only [role] and [search] are sent to the backend; cohort / sort /
/// "미배정(unassigned)" are applied CLIENT-SIDE (see [UserViewOptions]) because
/// the backend exposes neither a sort param nor a null-cohort filter.
///
/// NOTE: cohort is intentionally NOT a server filter here. To make "미배정" and
/// in-screen cohort switching instant (and correct for null-cohort users), the
/// screen fetches a generous page (size=200, see [UserListNotifier._fetch]) and
/// filters/sorts the loaded set in memory.
class UserListArgs {
  const UserListArgs({this.role, this.search});

  final String? role;
  final String? search;

  UserListArgs copyWith({
    String? role,
    bool clearRole = false,
    String? search,
    bool clearSearch = false,
  }) {
    return UserListArgs(
      role: clearRole ? null : (role ?? this.role),
      search: clearSearch ? null : (search ?? this.search),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserListArgs && other.role == role && other.search == search;

  @override
  int get hashCode => Object.hash(role, search);
}

/// The current SERVER-SIDE user-list filter. The screen mutates this;
/// [UserListNotifier] watches it (via the family key) to refetch.
final userListFilterProvider =
    NotifierProvider<UserListFilterNotifier, UserListArgs>(
  UserListFilterNotifier.new,
);

class UserListFilterNotifier extends Notifier<UserListArgs> {
  @override
  UserListArgs build() => const UserListArgs();

  void setRole(String? role) => state =
      role == null ? state.copyWith(clearRole: true) : state.copyWith(role: role);

  void setSearch(String search) => state = search.isEmpty
      ? state.copyWith(clearSearch: true)
      : state.copyWith(search: search);

  void reset() => state = const UserListArgs();
}

/// Sort field for the client-side user-list sort (#5-3).
enum UserSortField { createdAt, name, email }

/// Sentinel cohort-dropdown value meaning "미배정"(no cohort). Used by the user
/// tab's 기수 dropdown so "미배정" is just another option in the SAME dropdown
/// (운영 #1) rather than a separate toggle. It maps to
/// [UserViewOptions.unassignedOnly] in [UserViewOptionsNotifier.selectCohortDropdown].
/// A negative value can never collide with a real cohort id.
const int kUnassignedCohortValue = -1;

/// CLIENT-SIDE view options applied on top of the fetched page: cohort filter,
/// "미배정"(no-cohort) filter, and sort. These do NOT trigger a refetch — the
/// screen reads them and transforms the already-loaded [UserPage.users].
class UserViewOptions {
  const UserViewOptions({
    this.cohortId,
    this.unassignedOnly = false,
    this.sortField = UserSortField.createdAt,
    this.sortDescending = true,
  });

  /// Client-side cohort filter (matched against [AdminUser.cohortId]). Ignored
  /// when [unassignedOnly] is true.
  final int? cohortId;

  /// When true, show only users with no cohort (`cohortId == null`).
  final bool unassignedOnly;

  final UserSortField sortField;
  final bool sortDescending;

  /// The value the merged 기수 dropdown should show for this state (운영 #1):
  /// the 미배정 sentinel when [unassignedOnly], the concrete [cohortId]
  /// otherwise, or null for 기수 전체.
  int? get cohortDropdownValue =>
      unassignedOnly ? kUnassignedCohortValue : cohortId;

  UserViewOptions copyWith({
    int? cohortId,
    bool clearCohort = false,
    bool? unassignedOnly,
    UserSortField? sortField,
    bool? sortDescending,
  }) {
    return UserViewOptions(
      cohortId: clearCohort ? null : (cohortId ?? this.cohortId),
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
    );
  }
}

/// Drives the client-side view options (cohort / 미배정 / sort) for the user tab.
final userViewOptionsProvider =
    NotifierProvider<UserViewOptionsNotifier, UserViewOptions>(
  UserViewOptionsNotifier.new,
);

class UserViewOptionsNotifier extends Notifier<UserViewOptions> {
  @override
  UserViewOptions build() => const UserViewOptions();

  /// Selecting a concrete cohort clears the "미배정" filter (they're exclusive).
  void setCohort(int? cohortId) => state = cohortId == null
      ? state.copyWith(clearCohort: true)
      : state.copyWith(cohortId: cohortId, unassignedOnly: false);

  /// Turning on "미배정" clears any concrete cohort selection.
  void setUnassignedOnly(bool value) => state = value
      ? state.copyWith(unassignedOnly: true, clearCohort: true)
      : state.copyWith(unassignedOnly: false);

  /// Single entry point for the merged 기수 dropdown (운영 #1). The dropdown's
  /// value is interpreted as:
  ///   - null                   → 기수 전체 (clear both filters)
  ///   - [kUnassignedCohortValue] → 미배정 (unassignedOnly = true)
  ///   - any other id           → that concrete cohort
  void selectCohortDropdown(int? value) {
    if (value == null) {
      state = state.copyWith(clearCohort: true, unassignedOnly: false);
    } else if (value == kUnassignedCohortValue) {
      setUnassignedOnly(true);
    } else {
      setCohort(value);
    }
  }

  void setSortField(UserSortField field) =>
      state = state.copyWith(sortField: field);

  void setSortDescending(bool descending) =>
      state = state.copyWith(sortDescending: descending);

  void reset() => state = const UserViewOptions();
}

/// Applies the client-side [UserViewOptions] to a fetched [page]: filters by
/// cohort / 미배정, then sorts. Kept here (not in the widget) so the policy is
/// testable and shared. The result is correct for the LOADED set only — see
/// [UserListNotifier._fetch] for the page size we fetch up front.
List<AdminUser> applyUserView(List<AdminUser> users, UserViewOptions view) {
  Iterable<AdminUser> filtered = users;
  if (view.unassignedOnly) {
    filtered = filtered.where((u) => u.cohortId == null);
  } else if (view.cohortId != null) {
    filtered = filtered.where((u) => u.cohortId == view.cohortId);
  }

  final list = filtered.toList();
  int cmp(AdminUser a, AdminUser b) {
    switch (view.sortField) {
      case UserSortField.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case UserSortField.email:
        return a.email.toLowerCase().compareTo(b.email.toLowerCase());
      case UserSortField.createdAt:
        final ad = a.createdAt;
        final bd = b.createdAt;
        if (ad == null && bd == null) return a.id.compareTo(b.id);
        if (ad == null) return -1;
        if (bd == null) return 1;
        return ad.compareTo(bd);
    }
  }

  list.sort((a, b) => view.sortDescending ? cmp(b, a) : cmp(a, b));
  return list;
}

/// Loads a page of users for the given SERVER-SIDE filter [args] (captured by
/// the family factory — Riverpod 3.x non-codegen notifiers receive the key in
/// the ctor).
///
/// Fetches a generous page (size 200) so the screen's client-side cohort /
/// 미배정 / sort operations cover the whole filtered population without paging.
/// Holds the [Pagination] alongside the list so the screen can show counts.
class UserListNotifier extends AsyncNotifier<UserPage> {
  UserListNotifier(this.args);

  final UserListArgs args;

  /// Page size large enough to load the full user set for client-side
  /// filtering/sorting (the backend lacks a sort param + null-cohort filter).
  static const int clientSidePageSize = 200;

  @override
  Future<UserPage> build() => _fetch();

  Future<UserPage> _fetch() => ref.read(adminRepositoryProvider).listUsers(
        role: args.role,
        search: args.search,
        size: clientSidePageSize,
      );

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Optimistically flips a user's active flag in the loaded page (used after a
  /// deactivate/reactivate so the table reflects it without a round-trip).
  void patchActiveLocally(int userId, bool isActive) {
    final page = state.value;
    if (page == null) return;
    final updated = page.users
        .map((u) => u.id == userId
            ? AdminUser(
                id: u.id,
                email: u.email,
                name: u.name,
                role: u.role,
                isActive: isActive,
                cohortId: u.cohortId,
                nickname: u.nickname,
                phone: u.phone,
                institutionId: u.institutionId,
                lastLoginAt: u.lastLoginAt,
                createdAt: u.createdAt,
              )
            : u)
        .toList();
    state = AsyncData(UserPage(users: updated, pagination: page.pagination));
  }
}

final userListProvider =
    AsyncNotifierProvider.family<UserListNotifier, UserPage, UserListArgs>(
  UserListNotifier.new,
);

/// Imperative user mutations (role change, activate/deactivate, password
/// reset). Returns results / throws [AdminException] so the screen can surface
/// feedback; the list is refreshed by the caller via [userListProvider].
class UserActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> changeRole(int userId, {required String role, int? cohortId}) {
    return _repo.updateUserRole(userId, role: role, cohortId: cohortId);
  }

  Future<void> deactivate(int userId) => _repo.deactivateUser(userId);

  /// Reactivation maps to a profile patch; the backend treats `is_active` via
  /// the update endpoint. We send it through [AdminRepository.updateUser].
  Future<void> reactivate(int userId) =>
      _repo.updateUser(userId, {'is_active': true});

  Future<PasswordResetResult> resetPassword(int userId) =>
      _repo.resetPassword(userId);

  Future<AdminUser> createUser(AdminUserCreate body) =>
      _repo.createUser(body);

  /// Assigns / changes a user's cohort from the user tab (#5-1) via
  /// `POST /cohorts/{id}/members`. The member [role] determines the backend
  /// path: a 'student' updates `user.cohort_id`; an 'instructor' gets an
  /// `instructor_cohorts` row. Returns the add summary so the caller can report
  /// whether the assignment was newly added or skipped (already a member).
  Future<MembersAddResult> assignToCohort(
    int userId, {
    required int cohortId,
    required String role,
  }) {
    return _repo.addMembers(cohortId, userIds: [userId], role: role);
  }

  /// Removes an instructor's assignment to [cohortId] (운영 #2) via
  /// `DELETE /cohorts/{id}/members/{user_id}`. Because an instructor can hold
  /// MULTIPLE cohorts, removing one leaves the others intact.
  Future<void> unassignFromCohort(int userId, {required int cohortId}) {
    return _repo.removeMember(cohortId, userId);
  }
}

final userActionsProvider =
    NotifierProvider<UserActionsNotifier, void>(UserActionsNotifier.new);

/// ─────────────────────────────────────────────────────────────────────────
/// Bulk import — file-selection seam
/// ─────────────────────────────────────────────────────────────────────────

/// A picked CSV file: its name and raw bytes. Returned by [BulkImportPicker].
class PickedFile {
  const PickedFile({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

/// Picks a CSV file for bulk import, or returns null if the user cancels.
///
/// Backed by the `file_picker` package via [file_pick.pickFiles], restricted to
/// `.csv` and invoked with `withData: true` so bytes are available on Flutter
/// Web. Returns null when the user cancels the dialog.
typedef BulkImportPicker = Future<PickedFile?> Function();

/// CSV bulk-import picker wired to `file_picker`.
final bulkImportPickerProvider = Provider<BulkImportPicker>(
  (ref) => () async {
    final picked = await file_pick.pickFiles(extensions: ['csv']);
    if (picked.isEmpty) return null;
    final file = picked.first;
    return PickedFile(fileName: file.fileName, bytes: file.bytes);
  },
);

/// Whether a real bulk-import file picker is wired in. Now that `file_picker`
/// backs [bulkImportPickerProvider], this is true.
final bulkImportAvailableProvider = Provider<bool>((ref) => true);

/// Drives the bulk-import flow: pick a file (via the seam) → POST it → expose
/// the [BulkImportResult]. Surfaces errors through [BulkImportState.error].
class BulkImportState {
  const BulkImportState({
    this.isBusy = false,
    this.result,
    this.error,
    this.unavailable = false,
  });

  final bool isBusy;
  final BulkImportResult? result;
  final String? error;

  /// True when no file picker is wired in (the "준비 중" case).
  final bool unavailable;

  BulkImportState copyWith({
    bool? isBusy,
    BulkImportResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
    bool? unavailable,
  }) {
    return BulkImportState(
      isBusy: isBusy ?? this.isBusy,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      unavailable: unavailable ?? this.unavailable,
    );
  }
}

class BulkImportNotifier extends Notifier<BulkImportState> {
  @override
  BulkImportState build() => const BulkImportState();

  /// Runs the full pick → upload flow. A null pick means the user cancelled the
  /// file picker — that's a silent no-op (back to idle), not an error.
  Future<void> run() async {
    if (state.isBusy) return;
    state = const BulkImportState(isBusy: true);
    try {
      final picked = await ref.read(bulkImportPickerProvider)();
      if (picked == null) {
        state = const BulkImportState(); // cancelled → idle
        return;
      }
      final result = await ref.read(adminRepositoryProvider).bulkImport(
            fileName: picked.fileName,
            bytes: picked.bytes,
          );
      state = BulkImportState(result: result);
    } catch (e) {
      state = BulkImportState(error: e.toString());
    }
  }

  void clear() => state = const BulkImportState();
}

final bulkImportProvider =
    NotifierProvider<BulkImportNotifier, BulkImportState>(
  BulkImportNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Cohort management
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the institution's cohorts (used for both the cohort screen and the
/// user-filter cohort dropdown). Pulls a generous page so the dropdown is
/// complete without paging.
class CohortListNotifier extends AsyncNotifier<List<Cohort>> {
  @override
  Future<List<Cohort>> build() => _fetch();

  Future<List<Cohort>> _fetch() async {
    final page = await ref.read(adminRepositoryProvider).listCohorts();
    return page.cohorts;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final cohortListProvider =
    AsyncNotifierProvider<CohortListNotifier, List<Cohort>>(
  CohortListNotifier.new,
);

/// Member counts (수강생 / 강사) for a single cohort.
///
/// The `GET /cohorts/` LIST payload (`CohortOut`) does NOT carry counts — they
/// live only on `CohortDetail` returned by `GET /cohorts/{id}`. So the cohort
/// table cannot read counts off the list row (they would always be 0/0).
/// [cohortCountsProvider] resolves them per cohort id by fetching the detail.
class CohortCounts {
  const CohortCounts({required this.studentCount, required this.instructorCount});

  final int studentCount;
  final int instructorCount;
}

/// Fetches a single cohort's member counts via `GET /cohorts/{id}` (detail).
///
/// Keyed by cohort id and cached by Riverpod, so each row resolves its counts
/// exactly once and does NOT refetch on rebuild. Invalidated together with
/// [cohortListProvider] when membership changes (see the cohort screen's
/// refresh path). The screen renders a "—" placeholder while this is loading
/// and silently falls back to "—" on error rather than blocking the row.
final cohortCountsProvider =
    FutureProvider.family<CohortCounts, int>((ref, cohortId) async {
  final cohort = await ref.read(adminRepositoryProvider).getCohort(cohortId);
  return CohortCounts(
    studentCount: cohort.studentCount,
    instructorCount: cohort.instructorCount,
  );
});

/// Maps a cohort id to its display name, built from [cohortListProvider]. Used
/// by the user tab to render a user's 기수 by name (the `/users/` payload only
/// carries `cohort_id`, not the name — see #6-1). Returns an empty map while
/// the cohort list is still loading / errored.
final cohortNamesByIdProvider = Provider<Map<int, String>>((ref) {
  final cohorts = ref.watch(cohortListProvider).value ?? const <Cohort>[];
  return {for (final c in cohorts) c.id: c.name};
});

/// Maps an instructor's user id → the cohort names they are assigned to teach
/// (#6-1). The `/users/` list payload does NOT expose an instructor's teaching
/// cohorts (those live in the backend `instructor_cohorts` table, surfaced only
/// via `GET /cohorts/{id}/members?role=instructor`). So we fan out across every
/// cohort, read its instructor members, and invert the mapping.
///
/// This is O(number of cohorts) requests; acceptable for the operations cohort
/// count and cached by Riverpod until invalidated. Failures degrade gracefully
/// to an empty map (the row then falls back to showing nothing for instructors).
final instructorCohortNamesProvider =
    FutureProvider<Map<int, List<String>>>((ref) async {
  // Derive the name lists from the id-keyed map so the two views never drift.
  final byId = await ref.watch(instructorCohortsProvider.future);
  return {
    for (final entry in byId.entries)
      entry.key: [for (final c in entry.value) c.name],
  };
});

/// Maps an instructor's user id → the FULL list of cohorts (id + name) they are
/// assigned to teach (운영 #2). Unlike [instructorCohortNamesProvider] this
/// keeps the cohort id, which the "기수 배정/변경" dialog needs to REMOVE an
/// assignment (`DELETE /cohorts/{id}/members/{user_id}`).
///
/// Built by fanning out over every cohort's instructor members and inverting
/// the mapping — the same O(number of cohorts) scan, surfaced once and reused
/// by both providers. An instructor can appear under MANY cohorts.
final instructorCohortsProvider =
    FutureProvider<Map<int, List<Cohort>>>((ref) async {
  final cohorts = ref.watch(cohortListProvider).value ?? const <Cohort>[];
  if (cohorts.isEmpty) return const <int, List<Cohort>>{};
  final repo = ref.read(adminRepositoryProvider);
  final result = <int, List<Cohort>>{};
  for (final c in cohorts) {
    final members = await repo.listMembers(c.id, role: 'instructor');
    for (final m in members) {
      (result[m.id] ??= <Cohort>[]).add(c);
    }
  }
  return result;
});

/// Imperative cohort mutations. The screen refreshes [cohortListProvider] after
/// a successful create / edit / archive.
class CohortActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<Cohort> create(CohortCreate body) => _repo.createCohort(body);

  Future<Cohort> update(int cohortId, CohortUpdate body) =>
      _repo.updateCohort(cohortId, body);

  Future<void> archive(int cohortId) => _repo.archiveCohort(cohortId);
}

final cohortActionsProvider =
    NotifierProvider<CohortActionsNotifier, void>(CohortActionsNotifier.new);

/// Loads the members of a given cohort (captured in [cohortId]).
class CohortMembersNotifier extends AsyncNotifier<List<CohortMember>> {
  CohortMembersNotifier(this.cohortId);

  final int cohortId;

  @override
  Future<List<CohortMember>> build() => _fetch();

  Future<List<CohortMember>> _fetch() =>
      ref.read(adminRepositoryProvider).listMembers(cohortId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Adds members, then refreshes the thread. Throws [AdminException] on
  /// failure so the caller can surface it.
  Future<MembersAddResult> add({
    required List<int> userIds,
    required String role,
  }) async {
    final result = await ref.read(adminRepositoryProvider).addMembers(
          cohortId,
          userIds: userIds,
          role: role,
        );
    await refresh();
    return result;
  }

  /// Removes a member, optimistically dropping them from the list first.
  Future<void> remove(int userId) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(previous.where((m) => m.id != userId).toList());
    }
    try {
      await ref.read(adminRepositoryProvider).removeMember(cohortId, userId);
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final cohortMembersProvider = AsyncNotifierProvider.family<
    CohortMembersNotifier, List<CohortMember>, int>(
  CohortMembersNotifier.new,
);
