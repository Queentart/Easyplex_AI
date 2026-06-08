import '../../../../core/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
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

/// Operations-team cohort management (`/ops/cohorts`).
///
/// Tablet/PC-first: cohort data table with create/edit, archive (confirm
/// dialog), and per-cohort member management. admin_ops only.
class CohortManagementScreen extends ConsumerStatefulWidget {
  const CohortManagementScreen({super.key});

  @override
  ConsumerState<CohortManagementScreen> createState() =>
      _CohortManagementScreenState();
}

class _CohortManagementScreenState
    extends ConsumerState<CohortManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role;
    if (role != AppRoles.adminOps) {
      return const _AccessDenied();
    }

    final cohortsAsync = ref.watch(cohortListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(onCreate: _openCreate),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: cohortsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: LoadingView(message: '기수 목록을 불러오는 중입니다'),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(cohortListProvider.notifier).refresh(),
                ),
              ),
              data: (cohorts) => cohorts.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: EmptyState(
                        icon: Icons.school_outlined,
                        title: '등록된 기수가 없습니다',
                        description: '첫 기수를 만들어 수강생과 강사를 배정하세요.',
                        action: AppButton(
                          label: '기수 만들기',
                          icon: Icons.add_rounded,
                          onPressed: _openCreate,
                        ),
                      ),
                    )
                  : _CohortTable(
                      cohorts: cohorts,
                      onEdit: _openEdit,
                      onArchive: _archive,
                      onMembers: _openMembers,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CohortFormDialog(),
    );
    if (created == true) {
      _snack('기수를 만들었습니다.');
      ref.read(cohortListProvider.notifier).refresh();
    }
  }

  Future<void> _openEdit(Cohort cohort) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _CohortFormDialog(existing: cohort),
    );
    if (updated == true) {
      _snack('기수 정보를 수정했습니다.');
      ref.read(cohortListProvider.notifier).refresh();
    }
  }

  Future<void> _archive(Cohort cohort) async {
    final ok = await showConfirmDialog(
      context,
      title: '기수를 보관하시겠습니까?',
      message: '${cohort.name} 기수가 보관 처리됩니다. 이 작업은 되돌리기 어렵습니다.',
      confirmLabel: '보관',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(cohortActionsProvider.notifier).archive(cohort.id);
      _snack('기수를 보관했습니다.');
      ref.read(cohortListProvider.notifier).refresh();
    } on AdminException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _openMembers(Cohort cohort) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _MembersDialog(cohort: cohort),
    );
    // Member changes affect the 인원 counts (resolved from `/cohorts/{id}`):
    // refresh the list and drop the cached count so the row refetches it.
    ref.read(cohortListProvider.notifier).refresh();
    ref.invalidate(cohortCountsProvider(cohort.id));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLabels.cohortManagement, style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '기수를 만들고 수강생·강사를 배정합니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        AppButton(
          label: '기수 만들기',
          icon: Icons.add_rounded,
          onPressed: onCreate,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Table
// ─────────────────────────────────────────────────────────────────────────

class _CohortTable extends StatelessWidget {
  const _CohortTable({
    required this.cohorts,
    required this.onEdit,
    required this.onArchive,
    required this.onMembers,
  });

  final List<Cohort> cohorts;
  final ValueChanged<Cohort> onEdit;
  final ValueChanged<Cohort> onArchive;
  final ValueChanged<Cohort> onMembers;

  StatusTone _tone(String status) {
    switch (status) {
      case 'active':
        return StatusTone.success;
      case 'planned':
        return StatusTone.info;
      case 'completed':
        return StatusTone.neutral;
      default:
        return StatusTone.warning;
    }
  }

  String _period(Cohort c) {
    if (c.startDate == null || c.endDate == null) return '-';
    return '${DateFormatter.date(c.startDate!)} ~ ${DateFormatter.date(c.endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      columns: const ['기수명', '코드', '기간', '인원', '상태', '관리'],
      columnFlex: const [3, 2, 4, 2, 2, 3],
      rows: [
        for (final c in cohorts)
          AppTableRow(
            cells: [
              Text(c.name, style: AppTypography.bodySm),
              Text(
                c.code,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              Text(
                _period(c),
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              _CohortCountsCell(cohortId: c.id),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: cohortStatusLabelKo(c.status),
                  tone: _tone(c.status),
                ),
              ),
              _RowActions(
                onMembers: () => onMembers(c),
                onEdit: () => onEdit(c),
                onArchive: () => onArchive(c),
              ),
            ],
          ),
      ],
    );
  }
}

/// Renders a cohort row's 수강생 / 강사 counts.
///
/// The `/cohorts/` list payload carries NO counts (they live only on the
/// `/cohorts/{id}` detail), so this cell resolves them via the cached
/// [cohortCountsProvider] family. Shows a "—" placeholder while loading and on
/// error, so a slow / failed count never blocks the rest of the row.
class _CohortCountsCell extends ConsumerWidget {
  const _CohortCountsCell({required this.cohortId});

  final int cohortId;

  static const String _placeholder = '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(cohortCountsProvider(cohortId));
    final label = countsAsync.when(
      data: (c) => '수강생 ${c.studentCount} · 강사 ${c.instructorCount}',
      loading: () => '수강생 $_placeholder · 강사 $_placeholder',
      error: (_, _) => '수강생 $_placeholder · 강사 $_placeholder',
    );
    return Text(label, style: AppTypography.bodySm);
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.onMembers,
    required this.onEdit,
    required this.onArchive,
  });

  final VoidCallback onMembers;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.group_outlined, size: 20),
            color: AppColors.outline,
            tooltip: '구성원 관리',
            onPressed: onMembers,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.outline,
            tooltip: '수정',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, size: 20),
            color: AppColors.outline,
            tooltip: '보관',
            onPressed: onArchive,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Create / edit cohort dialog
// ─────────────────────────────────────────────────────────────────────────

class _CohortFormDialog extends ConsumerStatefulWidget {
  const _CohortFormDialog({this.existing});

  final Cohort? existing;

  @override
  ConsumerState<_CohortFormDialog> createState() => _CohortFormDialogState();
}

class _CohortFormDialogState extends ConsumerState<_CohortFormDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _codeController =
      TextEditingController(text: widget.existing?.code ?? '');
  late final TextEditingController _hoursController = TextEditingController(
      text: widget.existing?.totalHours?.toString() ?? '');
  late final TextEditingController _leaveAllowanceController =
      TextEditingController(
          text: widget.existing?.leaveAllowanceDays?.toString() ?? '');
  late final TextEditingController _descController =
      TextEditingController(text: widget.existing?.description ?? '');

  late DateTime? _startDate = widget.existing?.startDate;
  late DateTime? _endDate = widget.existing?.endDate;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _hoursController.dispose();
    _leaveAllowanceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _codeController.text.trim().isNotEmpty &&
      _startDate != null &&
      _endDate != null &&
      _leaveAllowanceError == null;

  /// Validates the (optional) leave-allowance field: empty = 미설정/null,
  /// otherwise a non-negative integer. Returns a Korean error or null when ok.
  String? get _leaveAllowanceError {
    final raw = _leaveAllowanceController.text.trim();
    if (raw.isEmpty) return null;
    final value = int.tryParse(raw);
    if (value == null || value < 0) return '0 이상의 정수를 입력하세요.';
    return null;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final hours = int.tryParse(_hoursController.text.trim());
    final leaveAllowance = int.tryParse(_leaveAllowanceController.text.trim());
    final desc = _descController.text.trim();
    try {
      if (_isEdit) {
        await ref.read(cohortActionsProvider.notifier).update(
              widget.existing!.id,
              CohortUpdate(
                name: _nameController.text.trim(),
                startDate: _startDate,
                endDate: _endDate,
                totalHours: hours,
                leaveAllowanceDays: leaveAllowance,
                description: desc,
              ),
            );
      } else {
        await ref.read(cohortActionsProvider.notifier).create(
              CohortCreate(
                name: _nameController.text.trim(),
                code: _codeController.text.trim(),
                startDate: _startDate!,
                endDate: _endDate!,
                totalHours: hours,
                leaveAllowanceDays: leaveAllowance,
                description: desc.isEmpty ? null : desc,
              ),
            );
      }
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
      title: Text(_isEdit ? '기수 수정' : '기수 만들기',
          style: AppTypography.headlineSm),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '기수명',
                  hintText: '예: 2026 AI 1기',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _codeController,
                enabled: !_isEdit, // code is immutable after creation
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '코드',
                  hintText: '예: AI-2026-01',
                  helperText: _isEdit ? '코드는 변경할 수 없습니다.' : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: '시작일',
                      value: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DateField(
                      label: '종료일',
                      value: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '총 교육시간 (선택)',
                  suffixText: '시간',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _leaveAllowanceController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '휴가 한도(일) (선택)',
                  hintText: '비워두면 미설정',
                  suffixText: '일',
                  helperText: '수강생 1인당 사용 가능한 휴가 일수',
                  errorText: _leaveAllowanceError,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '설명 (선택)',
                  alignLabelWithHint: true,
                ),
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
          label: _isEdit ? '저장' : '만들기',
          loading: _submitting,
          onPressed: _isValid && !_submitting ? _submit : null,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? '선택' : DateFormatter.date(value!),
          style: AppTypography.bodyMd.copyWith(
            color: value == null
                ? AppColors.onSurfaceVariant
                : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Members dialog
// ─────────────────────────────────────────────────────────────────────────

class _MembersDialog extends ConsumerWidget {
  const _MembersDialog({required this.cohort});

  final Cohort cohort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(cohortMembersProvider(cohort.id));

    Future<void> addMembers() async {
      final added = await showDialog<bool>(
        context: context,
        builder: (_) => _AddMembersDialog(cohort: cohort),
      );
      if (added == true && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('구성원을 추가했습니다.')));
      }
    }

    Future<void> remove(CohortMember member) async {
      final ok = await showConfirmDialog(
        context,
        title: '구성원을 제외하시겠습니까?',
        message: '${member.name} 님을 ${cohort.name} 기수에서 제외합니다.',
        confirmLabel: '제외',
        destructive: true,
      );
      if (!ok) return;
      try {
        await ref
            .read(cohortMembersProvider(cohort.id).notifier)
            .remove(member.id);
      } on AdminException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${cohort.name} · 구성원',
                        style: AppTypography.headlineSm),
                  ),
                  AppButton(
                    label: '구성원 추가',
                    icon: Icons.person_add_alt_1_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: addMembers,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: membersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: LoadingView(message: '구성원을 불러오는 중입니다'),
                  ),
                  error: (e, _) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: ErrorView(
                      message: e.toString(),
                      onRetry: () => ref
                          .read(cohortMembersProvider(cohort.id).notifier)
                          .refresh(),
                    ),
                  ),
                  data: (members) => members.isEmpty
                      ? const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: EmptyState(
                            icon: Icons.person_off_outlined,
                            title: '배정된 구성원이 없습니다',
                            description: '"구성원 추가"로 수강생·강사를 배정하세요.',
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.outlineVariant,
                          ),
                          itemBuilder: (_, i) {
                            final m = members[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(m.name, style: AppTypography.bodyMd),
                              subtitle: Text(
                                m.email,
                                style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant),
                              ),
                              leading: StatusChip(
                                label: roleLabelKo(m.role),
                                tone: StatusTone.info,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove_outlined,
                                    size: 20),
                                color: AppColors.outline,
                                tooltip: '제외',
                                onPressed: () => remove(m),
                              ),
                            );
                          },
                        ),
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
// Add-members dialog (#5-2)
// ─────────────────────────────────────────────────────────────────────────

/// Picks a member role then multi-selects users of that role to add to the
/// cohort via `POST /cohorts/{id}/members`. Candidate users are fetched with a
/// server-side role filter; the search box filters the loaded set client-side.
class _AddMembersDialog extends ConsumerStatefulWidget {
  const _AddMembersDialog({required this.cohort});

  final Cohort cohort;

  @override
  ConsumerState<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends ConsumerState<_AddMembersDialog> {
  String _role = AppRoles.student;
  final Set<int> _selected = {};
  String _query = '';
  bool _submitting = false;
  String? _error;

  void _setRole(String role) {
    if (role == _role) return;
    setState(() {
      _role = role;
      _selected.clear();
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(cohortMembersProvider(widget.cohort.id).notifier).add(
            userIds: _selected.toList(),
            role: _role,
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
    // Fetch candidate users filtered by the chosen role (server-side).
    final args = UserListArgs(role: _role);
    final usersAsync = ref.watch(userListProvider(args));

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      title: Text('구성원 추가 · ${widget.cohort.name}',
          style: AppTypography.headlineSm),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: AppRoles.student, label: Text('수강생')),
                ButtonSegment(value: AppRoles.instructor, label: Text('강사')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => _setRole(s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                labelText: '검색',
                hintText: '이름 또는 이메일',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: usersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: LoadingView(message: '사용자를 불러오는 중입니다'),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: ErrorView(
                    message: e.toString(),
                    onRetry: () =>
                        ref.read(userListProvider(args).notifier).refresh(),
                  ),
                ),
                data: (page) {
                  final candidates = page.users.where((u) {
                    if (!u.isActive) return false;
                    if (_query.isEmpty) return true;
                    return u.name.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query);
                  }).toList();
                  if (candidates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: EmptyState(
                        icon: Icons.person_search_outlined,
                        title: '추가할 사용자가 없습니다',
                        description: '역할이나 검색어를 변경해보세요.',
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, i) {
                      final u = candidates[i];
                      final checked = _selected.contains(u.id);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: checked,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(u.id);
                          } else {
                            _selected.remove(u.id);
                          }
                        }),
                        title: Text(u.name, style: AppTypography.bodyMd),
                        subtitle: Text(
                          u.email,
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ],
          ],
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
          label: _selected.isEmpty ? '추가' : '추가 (${_selected.length})',
          loading: _submitting,
          onPressed: _selected.isEmpty || _submitting ? null : _submit,
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
        description: '기수 관리는 운영팀만 이용할 수 있습니다.',
      ),
    );
  }
}
