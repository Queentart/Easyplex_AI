import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cohort_filter.dart';
import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_model.dart';
import '../admin_provider.dart';

/// Operations-team user management (`/ops/users`).
///
/// Tablet/PC-first data table: search + role/cohort filters, per-row role
/// change, activate/deactivate (confirm dialog), password reset, plus user
/// create and a CSV bulk-import seam. admin_ops only — other roles see an
/// access notice.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();

  /// One-time guard so the global cohort selection only PRE-FILLS the in-screen
  /// cohort filter once (it stays overridable thereafter).
  bool _seededCohort = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role;
    if (role != AppRoles.adminOps) {
      return const _AccessDenied();
    }

    // Pre-fill the in-screen cohort filter from the global selection ONCE.
    final selectedCohort = ref.watch(selectedCohortProvider);
    if (!_seededCohort) {
      _seededCohort = true;
      if (selectedCohort != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(userViewOptionsProvider.notifier).setCohort(selectedCohort);
          }
        });
      }
    }

    final filter = ref.watch(userListFilterProvider);
    final view = ref.watch(userViewOptionsProvider);
    final usersAsync = ref.watch(userListProvider(filter));
    final cohortsAsync = ref.watch(cohortListProvider);
    final cohortNames = ref.watch(cohortNamesByIdProvider);
    final instructorCohorts =
        ref.watch(instructorCohortNamesProvider).value ?? const {};

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(
            onCreate: _openCreate,
            onBulkImport: _runBulkImport,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Filters(
            searchController: _searchController,
            filter: filter,
            view: view,
            cohorts: cohortsAsync.value ?? const [],
            onSearch: (v) =>
                ref.read(userListFilterProvider.notifier).setSearch(v),
            onRole: (v) =>
                ref.read(userListFilterProvider.notifier).setRole(v),
            onCohort: (v) => ref
                .read(userViewOptionsProvider.notifier)
                .selectCohortDropdown(v),
            onSortField: (v) =>
                ref.read(userViewOptionsProvider.notifier).setSortField(v),
            onSortDescending: (v) => ref
                .read(userViewOptionsProvider.notifier)
                .setSortDescending(v),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: usersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: LoadingView(message: '사용자 목록을 불러오는 중입니다'),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(userListProvider(filter).notifier).refresh(),
                ),
              ),
              data: (page) {
                final visible = applyUserView(page.users, view);
                return visible.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: EmptyState(
                          icon: Icons.group_off_outlined,
                          title: '조건에 맞는 사용자가 없습니다',
                          description: '검색어나 필터를 변경해 다시 시도해보세요.',
                        ),
                      )
                    : _UserTable(
                        users: visible,
                        totalLoaded: page.users.length,
                        cohortNames: cohortNames,
                        instructorCohorts: instructorCohorts,
                        onChangeRole: _changeRole,
                        onAssignCohort: _assignCohort,
                        onToggleActive: _toggleActive,
                        onResetPassword: _resetPassword,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  void _refreshList() {
    final filter = ref.read(userListFilterProvider);
    ref.read(userListProvider(filter).notifier).refresh();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeRole(AdminUser user) async {
    final cohorts = ref.read(cohortListProvider).value ?? const [];
    final result = await showDialog<_RoleChangeResult>(
      context: context,
      builder: (_) => _RoleChangeDialog(user: user, cohorts: cohorts),
    );
    if (result == null) return;
    try {
      await ref.read(userActionsProvider.notifier).changeRole(
            user.id,
            role: result.role,
            cohortId: result.cohortId,
          );
      _snack('${user.name} 님의 역할을 변경했습니다.');
      _refreshList();
    } on AdminException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _assignCohort(AdminUser user) async {
    final cohorts = ref.read(cohortListProvider).value ?? const [];
    if (cohorts.isEmpty) {
      _snack('먼저 기수를 만들어주세요.');
      return;
    }
    if (user.role != AppRoles.student && user.role != AppRoles.instructor) {
      _snack('수강생 또는 강사만 기수에 배정할 수 있습니다.');
      return;
    }

    // 운영 #2: an instructor can hold MULTIPLE cohorts, so they get a richer
    // dialog (current list + add + remove) that self-manages its mutations.
    // A student has a single cohort, so they keep the single-select flow.
    if (user.role == AppRoles.instructor) {
      await showDialog<void>(
        context: context,
        builder: (_) => _InstructorCohortsDialog(user: user, cohorts: cohorts),
      );
      // The dialog mutated assignments; refresh the dependent views.
      ref.invalidate(instructorCohortsProvider);
      ref.invalidate(instructorCohortNamesProvider);
      ref.read(cohortListProvider.notifier).refresh();
      return;
    }

    final cohortId = await showDialog<int>(
      context: context,
      builder: (_) => _AssignCohortDialog(user: user, cohorts: cohorts),
    );
    if (cohortId == null) return;
    try {
      final result =
          await ref.read(userActionsProvider.notifier).assignToCohort(
                user.id,
                cohortId: cohortId,
                role: user.role,
              );
      final cohortName = cohorts.firstWhere((c) => c.id == cohortId).name;
      _snack(result.added > 0
          ? '${user.name} 님을 $cohortName 기수에 배정했습니다.'
          : '${user.name} 님은 이미 $cohortName 기수에 배정되어 있습니다.');
      // Student assignments change user.cohort_id (shown in the list); refresh.
      _refreshList();
      // Member counts on the cohort screen may change too.
      ref.read(cohortListProvider.notifier).refresh();
    } on AdminException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _toggleActive(AdminUser user) async {
    final deactivating = user.isActive;
    final ok = await showConfirmDialog(
      context,
      title: deactivating ? '계정을 비활성화하시겠습니까?' : '계정을 활성화하시겠습니까?',
      message: deactivating
          ? '${user.name}(${user.email}) 님은 더 이상 로그인할 수 없습니다.'
          : '${user.name}(${user.email}) 님이 다시 로그인할 수 있습니다.',
      confirmLabel: deactivating ? '비활성화' : '활성화',
      destructive: deactivating,
    );
    if (!ok) return;

    // Optimistic flip; roll back on failure.
    final filter = ref.read(userListFilterProvider);
    ref
        .read(userListProvider(filter).notifier)
        .patchActiveLocally(user.id, !deactivating);
    try {
      if (deactivating) {
        await ref.read(userActionsProvider.notifier).deactivate(user.id);
      } else {
        await ref.read(userActionsProvider.notifier).reactivate(user.id);
      }
      _snack(deactivating ? '계정을 비활성화했습니다.' : '계정을 활성화했습니다.');
    } on AdminException catch (e) {
      ref
          .read(userListProvider(filter).notifier)
          .patchActiveLocally(user.id, deactivating);
      _snack(e.message);
    }
  }

  Future<void> _resetPassword(AdminUser user) async {
    final ok = await showConfirmDialog(
      context,
      title: '비밀번호를 초기화하시겠습니까?',
      message: '${user.name}(${user.email}) 님의 임시 비밀번호가 발급됩니다.',
      confirmLabel: '초기화',
    );
    if (!ok) return;
    try {
      final result =
          await ref.read(userActionsProvider.notifier).resetPassword(user.id);
      if (!mounted) return;
      if (result.temporaryPassword != null) {
        await showDialog<void>(
          context: context,
          builder: (_) => _TempPasswordDialog(
            user: user,
            temporaryPassword: result.temporaryPassword!,
          ),
        );
      } else {
        _snack(result.emailSent
            ? '임시 비밀번호를 이메일로 발송했습니다.'
            : '비밀번호를 초기화했습니다.');
      }
    } on AdminException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _openCreate() async {
    final cohorts = ref.read(cohortListProvider).value ?? const [];
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateUserDialog(cohorts: cohorts),
    );
    if (created == true) {
      _snack('사용자를 추가했습니다.');
      _refreshList();
    }
  }

  Future<void> _runBulkImport() async {
    ref.read(bulkImportProvider.notifier).clear();
    await ref.read(bulkImportProvider.notifier).run();
    if (!mounted) return;
    final state = ref.read(bulkImportProvider);
    if (state.unavailable) {
      _snack('일괄 등록(CSV) 기능은 준비 중입니다.');
    } else if (state.error != null) {
      _snack(state.error!);
    } else if (state.result != null) {
      final r = state.result!;
      _snack('일괄 등록 완료: 성공 ${r.imported}건, 실패 ${r.failed}건');
      _refreshList();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onCreate, required this.onBulkImport});

  final VoidCallback onCreate;
  final VoidCallback onBulkImport;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('사용자 관리', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '계정 생성, 역할 변경, 활성화 상태를 관리합니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            AppButton(
              label: '일괄 등록',
              icon: Icons.upload_file_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: onBulkImport,
            ),
            AppButton(
              label: '사용자 추가',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: onCreate,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filters
// ─────────────────────────────────────────────────────────────────────────

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.filter,
    required this.view,
    required this.cohorts,
    required this.onSearch,
    required this.onRole,
    required this.onCohort,
    required this.onSortField,
    required this.onSortDescending,
  });

  final TextEditingController searchController;
  final UserListArgs filter;
  final UserViewOptions view;
  final List<Cohort> cohorts;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onRole;

  /// Receives the merged 기수 dropdown value: null (기수 전체),
  /// [kUnassignedCohortValue] (미배정), or a concrete cohort id.
  final ValueChanged<int?> onCohort;
  final ValueChanged<UserSortField> onSortField;
  final ValueChanged<bool> onSortDescending;

  static const _sortLabels = {
    UserSortField.createdAt: '가입일',
    UserSortField.name: '이름',
    UserSortField.email: '이메일',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
              decoration: const InputDecoration(
                labelText: '검색',
                hintText: '이름 또는 이메일',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String?>(
              initialValue: filter.role,
              decoration: const InputDecoration(labelText: '역할'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 역할')),
                for (final r in AppRoles.all)
                  DropdownMenuItem(value: r, child: Text(roleLabelKo(r))),
              ],
              onChanged: onRole,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              // 운영 #1: "미배정" is now an option in THIS dropdown (a sentinel),
              // not a separate toggle. null = 기수 전체.
              initialValue: view.cohortDropdownValue,
              decoration: const InputDecoration(labelText: '기수'),
              items: [
                const DropdownMenuItem(value: null, child: Text('기수 전체')),
                const DropdownMenuItem(
                  value: kUnassignedCohortValue,
                  child: Text('미배정'),
                ),
                for (final c in cohorts)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: onCohort,
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<UserSortField>(
              initialValue: view.sortField,
              decoration: const InputDecoration(labelText: '정렬 기준'),
              items: [
                for (final entry in _sortLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) {
                if (v != null) onSortField(v);
              },
            ),
          ),
          // Sort direction toggle (오름차순 / 내림차순).
          Tooltip(
            message: view.sortDescending ? '내림차순' : '오름차순',
            child: OutlinedButton.icon(
              onPressed: () => onSortDescending(!view.sortDescending),
              icon: Icon(
                view.sortDescending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 18,
              ),
              label: Text(view.sortDescending ? '내림차순' : '오름차순'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Table
// ─────────────────────────────────────────────────────────────────────────

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.users,
    required this.totalLoaded,
    required this.cohortNames,
    required this.instructorCohorts,
    required this.onChangeRole,
    required this.onAssignCohort,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  /// The already-filtered/sorted users to display.
  final List<AdminUser> users;

  /// Total users loaded for the current server-side filter (before client-side
  /// cohort/미배정 filtering) — used for the footer count.
  final int totalLoaded;

  /// cohort id → name, for rendering a student's 기수 by name (#6-1).
  final Map<int, String> cohortNames;

  /// instructor user id → teaching cohort names (#6-1).
  final Map<int, List<String>> instructorCohorts;

  final ValueChanged<AdminUser> onChangeRole;
  final ValueChanged<AdminUser> onAssignCohort;
  final ValueChanged<AdminUser> onToggleActive;
  final ValueChanged<AdminUser> onResetPassword;

  /// Resolves the cohort cell text for a user (#6-1).
  ///  - student: their single 기수 (by name, falling back to the id).
  ///  - instructor: their 담당 기수(들), comma-joined.
  ///  - others: a dash.
  String _cohortText(AdminUser u) {
    if (u.role == AppRoles.instructor) {
      final names = instructorCohorts[u.id] ?? const [];
      return names.isEmpty ? '-' : names.join(', ');
    }
    if (u.role == AppRoles.student) {
      final id = u.cohortId;
      if (id == null) return '미배정';
      return cohortNames[id] ?? '기수 $id';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDataTable(
          columns: const ['이름', '이메일', '역할', '기수', '상태', '관리'],
          columnFlex: const [3, 4, 2, 3, 2, 2],
          rows: [
            for (final u in users)
              AppTableRow(
                highlight: !u.isActive,
                cells: [
                  Text(u.name, style: AppTypography.bodySm),
                  Text(
                    u.email,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(
                      label: roleLabelKo(u.role),
                      tone: StatusTone.info,
                    ),
                  ),
                  Text(
                    _cohortText(u),
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(
                      label: u.isActive ? '활성' : '비활성',
                      tone: u.isActive ? StatusTone.success : StatusTone.danger,
                    ),
                  ),
                  _RowActions(
                    user: u,
                    onChangeRole: () => onChangeRole(u),
                    onAssignCohort: () => onAssignCohort(u),
                    onToggleActive: () => onToggleActive(u),
                    onResetPassword: () => onResetPassword(u),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          users.length == totalLoaded
              ? '전체 ${users.length}명'
              : '표시 ${users.length}명 / 불러온 $totalLoaded명',
          style: AppTypography.labelSm
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.user,
    required this.onChangeRole,
    required this.onAssignCohort,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  final AdminUser user;
  final VoidCallback onChangeRole;
  final VoidCallback onAssignCohort;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    // Cohort assignment only makes sense for students / instructors (#5-1).
    final canAssignCohort =
        user.role == AppRoles.student || user.role == AppRoles.instructor;
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, color: AppColors.outline),
        tooltip: '관리',
        onSelected: (value) {
          switch (value) {
            case 'role':
              onChangeRole();
            case 'cohort':
              onAssignCohort();
            case 'active':
              onToggleActive();
            case 'reset':
              onResetPassword();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'role', child: Text('역할 변경')),
          if (canAssignCohort)
            const PopupMenuItem(value: 'cohort', child: Text('기수 배정/변경')),
          PopupMenuItem(
            value: 'active',
            child: Text(user.isActive ? '비활성화' : '활성화'),
          ),
          const PopupMenuItem(value: 'reset', child: Text('비밀번호 초기화')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Role-change dialog
// ─────────────────────────────────────────────────────────────────────────

class _RoleChangeResult {
  const _RoleChangeResult({required this.role, this.cohortId});

  final String role;
  final int? cohortId;
}

class _RoleChangeDialog extends StatefulWidget {
  const _RoleChangeDialog({required this.user, required this.cohorts});

  final AdminUser user;
  final List<Cohort> cohorts;

  @override
  State<_RoleChangeDialog> createState() => _RoleChangeDialogState();
}

class _RoleChangeDialogState extends State<_RoleChangeDialog> {
  late String _role = widget.user.role;
  late int? _cohortId = widget.user.cohortId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      title: Text('역할 변경 · ${widget.user.name}',
          style: AppTypography.headlineSm),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: '역할'),
            items: [
              for (final r in AppRoles.all)
                DropdownMenuItem(value: r, child: Text(roleLabelKo(r))),
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int?>(
            initialValue: _cohortId,
            decoration: const InputDecoration(labelText: '기수 (선택)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('미지정')),
              for (final c in widget.cohorts)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _cohortId = v),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: '취소',
          variant: AppButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: '저장',
          onPressed: () => Navigator.of(context).pop(
            _RoleChangeResult(role: _role, cohortId: _cohortId),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Assign-cohort dialog — STUDENT (single cohort) (#5-1)
// ─────────────────────────────────────────────────────────────────────────

/// Single-select cohort assignment for a STUDENT. A student has exactly one
/// cohort (`users.cohort_id`), so this returns the chosen id (or null on
/// cancel). Instructors use [_InstructorCohortsDialog] instead (운영 #2).
class _AssignCohortDialog extends StatefulWidget {
  const _AssignCohortDialog({required this.user, required this.cohorts});

  final AdminUser user;
  final List<Cohort> cohorts;

  @override
  State<_AssignCohortDialog> createState() => _AssignCohortDialogState();
}

class _AssignCohortDialogState extends State<_AssignCohortDialog> {
  int? _cohortId;

  @override
  void initState() {
    super.initState();
    // Pre-select the student's current cohort, if any.
    _cohortId = widget.user.cohortId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      title: Text('기수 배정/변경 · ${widget.user.name}',
          style: AppTypography.headlineSm),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '수강생을 선택한 기수로 배정합니다.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              initialValue: _cohortId,
              decoration: const InputDecoration(labelText: '기수'),
              items: [
                const DropdownMenuItem(value: null, child: Text('기수 선택')),
                for (final c in widget.cohorts)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _cohortId = v),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: '취소',
          variant: AppButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: '배정',
          onPressed: _cohortId == null
              ? null
              : () => Navigator.of(context).pop(_cohortId),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Instructor multi-cohort dialog (운영 #2)
// ─────────────────────────────────────────────────────────────────────────

/// Manages an INSTRUCTOR's cohort assignments. Because an instructor can belong
/// to MULTIPLE cohorts (backend `instructor_cohorts` join table), this dialog
/// shows their CURRENT cohorts and lets the operator:
///   - ADD another cohort   → `POST /cohorts/{id}/members {user_ids,'instructor'}`
///   - REMOVE one assignment → `DELETE /cohorts/{id}/members/{user_id}`
///
/// It self-manages its mutations and reflects them by invalidating
/// [instructorCohortsProvider]; the caller refreshes the user list afterwards.
class _InstructorCohortsDialog extends ConsumerStatefulWidget {
  const _InstructorCohortsDialog({required this.user, required this.cohorts});

  final AdminUser user;
  final List<Cohort> cohorts;

  @override
  ConsumerState<_InstructorCohortsDialog> createState() =>
      _InstructorCohortsDialogState();
}

class _InstructorCohortsDialogState
    extends ConsumerState<_InstructorCohortsDialog> {
  int? _toAdd;

  /// Id of the cohort whose row is mid-mutation (add/remove), to disable its
  /// control and prevent duplicate submissions.
  int? _busyCohortId;
  bool _adding = false;
  String? _error;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final cohortId = _toAdd;
    if (cohortId == null || _adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final result = await ref.read(userActionsProvider.notifier).assignToCohort(
            widget.user.id,
            cohortId: cohortId,
            role: AppRoles.instructor,
          );
      final name = widget.cohorts.firstWhere((c) => c.id == cohortId).name;
      _snack(result.added > 0
          ? '$name 기수 담당으로 추가했습니다.'
          : '이미 $name 기수를 담당하고 있습니다.');
      ref.invalidate(instructorCohortsProvider);
      if (mounted) setState(() => _toAdd = null);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(Cohort cohort) async {
    if (_busyCohortId != null) return;
    final ok = await showConfirmDialog(
      context,
      title: '담당 기수에서 제외하시겠습니까?',
      message: '${widget.user.name} 님을 ${cohort.name} 기수 담당에서 제외합니다. '
          '다른 담당 기수는 유지됩니다.',
      confirmLabel: '제외',
      destructive: true,
    );
    if (!ok) return;
    setState(() {
      _busyCohortId = cohort.id;
      _error = null;
    });
    try {
      await ref.read(userActionsProvider.notifier).unassignFromCohort(
            widget.user.id,
            cohortId: cohort.id,
          );
      _snack('${cohort.name} 기수 담당에서 제외했습니다.');
      ref.invalidate(instructorCohortsProvider);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyCohortId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignedAsync = ref.watch(instructorCohortsProvider);
    final current = (assignedAsync.value ?? const <int, List<Cohort>>{})[
            widget.user.id] ??
        const <Cohort>[];
    final assignedIds = {for (final c in current) c.id};
    // Only offer cohorts the instructor does not already teach.
    final addable =
        widget.cohorts.where((c) => !assignedIds.contains(c.id)).toList();

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('담당 기수 · ${widget.user.name}',
                        style: AppTypography.headlineSm),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '강사는 여러 기수를 동시에 담당할 수 있습니다. 담당 기수를 추가하거나 제외하세요.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Current cohorts ───────────────────────────────────────────
              assignedAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: LoadingView(message: '담당 기수를 불러오는 중입니다'),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(instructorCohortsProvider),
                  ),
                ),
                data: (_) => current.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: EmptyState(
                          icon: Icons.school_outlined,
                          title: '담당 기수가 없습니다',
                          description: '아래에서 담당할 기수를 추가하세요.',
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: current.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.outlineVariant,
                          ),
                          itemBuilder: (_, i) {
                            final c = current[i];
                            final busy = _busyCohortId == c.id;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.school_outlined,
                                  color: AppColors.outline),
                              title:
                                  Text(c.name, style: AppTypography.bodyMd),
                              subtitle: Text(
                                c.code,
                                style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant),
                              ),
                              trailing: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                          Icons.person_remove_outlined,
                                          size: 20),
                                      color: AppColors.outline,
                                      tooltip: '담당 제외',
                                      onPressed: _busyCohortId != null
                                          ? null
                                          : () => _remove(c),
                                    ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.outlineVariant),
              const SizedBox(height: AppSpacing.md),
              // ── Add a cohort ──────────────────────────────────────────────
              Text('담당 기수 추가',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _toAdd,
                      decoration: const InputDecoration(labelText: '기수'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('기수 선택')),
                        for (final c in addable)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: _adding
                          ? null
                          : (v) => setState(() => _toAdd = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: '추가',
                    icon: Icons.add_rounded,
                    loading: _adding,
                    onPressed: _toAdd == null || _adding ? null : _add,
                  ),
                ],
              ),
              if (addable.isEmpty && current.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '모든 기수를 이미 담당하고 있습니다.',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style:
                      AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: '완료',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Create-user dialog
// ─────────────────────────────────────────────────────────────────────────

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog({required this.cohorts});

  final List<Cohort> cohorts;

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = AppRoles.student;
  int? _cohortId;
  bool _sendInvitation = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _emailController.text.trim().isNotEmpty &&
      _nameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(userActionsProvider.notifier).createUser(
            AdminUserCreate(
              email: _emailController.text.trim(),
              name: _nameController.text.trim(),
              role: _role,
              cohortId: _cohortId,
              phone: _phoneController.text.trim(),
              sendInvitation: _sendInvitation,
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on AdminException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      title: Text('사용자 추가', style: AppTypography.headlineSm),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '홍길동',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '이메일',
                  hintText: 'user@example.com',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '전화번호 (선택)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: '역할'),
                items: [
                  for (final r in AppRoles.all)
                    DropdownMenuItem(value: r, child: Text(roleLabelKo(r))),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int?>(
                initialValue: _cohortId,
                decoration: const InputDecoration(labelText: '기수 (선택)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('미지정')),
                  for (final c in widget.cohorts)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _cohortId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
                value: _sendInvitation,
                onChanged: (v) => setState(() => _sendInvitation = v),
                title: Text('초대 메일 발송', style: AppTypography.bodyMd),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style:
                      AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: '취소',
          variant: AppButtonVariant.tertiary,
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: '추가',
          loading: _submitting,
          onPressed: _isValid && !_submitting ? _submit : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Temp-password result dialog
// ─────────────────────────────────────────────────────────────────────────

class _TempPasswordDialog extends StatelessWidget {
  const _TempPasswordDialog({
    required this.user,
    required this.temporaryPassword,
  });

  final AdminUser user;
  final String temporaryPassword;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      title: Text('임시 비밀번호 발급', style: AppTypography.headlineSm),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${user.name}(${user.email}) 님의 임시 비밀번호입니다. 안전하게 전달하세요.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: SelectableText(
              temporaryPassword,
              style: AppTypography.bodyLg,
            ),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: '닫기',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Access denied (non-admin_ops)
// ─────────────────────────────────────────────────────────────────────────

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: EmptyState(
        icon: Icons.lock_outline_rounded,
        title: '접근 권한이 없습니다',
        description: '사용자 관리는 운영팀만 이용할 수 있습니다.',
      ),
    );
  }
}
