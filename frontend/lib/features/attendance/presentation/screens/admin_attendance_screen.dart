import '../../../../core/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cohort_filter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../attendance_management_provider.dart';
import 'attendance_roster_view.dart';

/// 운영팀(admin_ops) 전체 출결 관리 화면 — 표준 로스터(수강생별) 뷰.
///
/// Rendered inside the authenticated app shell (top bar + side nav are supplied
/// by the shell), so this widget returns page content only — no Scaffold/AppBar.
///
/// 구성:
///   - 상단 컨트롤: 기수(글로벌 [selectedCohortProvider]를 기본값으로, 화면에서 재정의
///     가능) + 기간(월) + 정렬 + "CSV 가져오기" 액션(→ /ops/attendance/import)
///   - 전체 출석률 / 인원수 / 지각·결석 합계 요약
///   - 수강생별 로스터 테이블(1인 1행, 위험 행 강조, 탭 시 일자별 기록 시트)
///
/// 백엔드에 로스터 엔드포인트가 없으므로 선택한 기수·기간의 출결 기록을
/// `GET /attendance/?cohort_id=&from_date=&to_date=`로 받아 클라이언트에서
/// 수강생별로 집계합니다(domain/attendance_roster.dart). 운영팀만 접근하며
/// 백엔드 require_roles가 권한을 강제하고, 비권한 응답은 403 메시지로 표시됩니다.
class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  /// In-screen cohort override. `null` means "follow the global selection"
  /// (which itself may be `null` = 전체 기수). Set when the ops user types a
  /// cohort id into the in-screen field.
  int? _cohortOverride;
  bool _hasOverride = false;

  @override
  Widget build(BuildContext context) {
    final globalCohort = ref.watch(selectedCohortProvider);
    final month = ref.watch(managementMonthProvider);
    final cohortId = _hasOverride ? _cohortOverride : globalCohort;

    final scope = RosterScope(cohortId: cohortId, month: month);
    final rosterAsync = ref.watch(adminRosterProvider(scope));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── 헤더 ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(AppLabels.attendanceManagement, style: AppTypography.headlineMd),
              ),
              AppButton(
                label: 'CSV 가져오기',
                icon: Icons.upload_file_outlined,
                onPressed: () => context.go('/ops/attendance/import'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '기수·기간별 수강생 출결 현황을 한눈에 확인하고 관리합니다.',
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          rosterAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: LoadingView(message: '출결 현황을 불러오는 중입니다…'),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: ErrorView(
                message: error.toString(),
                onRetry: () =>
                    ref.read(adminRosterProvider(scope).notifier).refresh(),
              ),
            ),
            data: (roster) => AttendanceRosterView(
              roster: roster,
              month: month,
              onSelectMonth: (m) =>
                  ref.read(managementMonthProvider.notifier).select(m),
              leadingControls: [
                _CohortFilterField(
                  // Re-key on the active cohort so resetting rebuilds the field
                  // with a cleared controller.
                  key: ValueKey(cohortId),
                  initialValue: cohortId,
                  onSubmitted: (id) => setState(() {
                    _cohortOverride = id;
                    _hasOverride = true;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric cohort-id filter field with a stable controller. Submitting (enter)
/// applies the filter; an empty value clears the cohort filter ("전체").
class _CohortFilterField extends StatefulWidget {
  const _CohortFilterField({
    super.key,
    required this.initialValue,
    required this.onSubmitted,
  });

  final int? initialValue;
  final ValueChanged<int?> onSubmitted;

  @override
  State<_CohortFilterField> createState() => _CohortFilterFieldState();
}

class _CohortFilterFieldState extends State<_CohortFilterField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '기수 ID',
          hintText: '예) 1 (비우면 전체)',
        ),
        onSubmitted: (value) => widget.onSubmitted(int.tryParse(value.trim())),
      ),
    );
  }
}
