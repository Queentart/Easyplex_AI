import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../widgets/mock_demo_banner.dart';

/// Operations · 데이터 동기화 · 무결성 제어 (MOCK-ONLY).
///
/// Faithful to the `data_sync_integrity_control_dashboard` Stitch mockup: sync
/// job status, a data-integrity cross-check table (고용24 ↔ Zoom), and
/// run/rollback controls.
///
/// ── DATA SOURCE ────────────────────────────────────────────────────────────
/// EVERY value is HARD-CODED demo data and the run/rollback/resolve buttons are
/// NO-OPS (they only show a SnackBar after a confirmation dialog). There is no
/// `/sync/status`, `/sync/run`, `/sync/jobs` or `/sync/integrity` endpoint yet.
/// See the repository seam at the bottom of this file. A visible "데모 데이터"
/// banner flags the mock state.
class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  static const String routePath = '/ops/sync';

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  bool _mockRunning = false;

  Future<void> _onRunCrossCheck() async {
    if (_mockRunning) return; // prevent duplicate submission
    final ok = await showConfirmDialog(
      context,
      title: '교차 검증을 실행하시겠습니까?',
      message: '고용24 기록과 Zoom 출결 로그를 대조합니다. (데모 모드 · 실제 실행 안 됨)',
      confirmLabel: '실행',
    );
    if (!ok || !mounted) return;
    setState(() => _mockRunning = true);
    // MOCK: no `/sync/run` endpoint — simulate a brief job for UX feedback.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _mockRunning = false);
    _snack('데모 모드입니다. 동기화는 실행되지 않습니다 (API 연동 전).');
  }

  Future<void> _onRollback() async {
    final ok = await showConfirmDialog(
      context,
      title: '마지막 동기화를 롤백하시겠습니까?',
      message: '직전 동기화 배치를 되돌립니다. 이 작업은 되돌릴 수 없습니다. (데모 모드 · 실제 실행 안 됨)',
      confirmLabel: '롤백',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _snack('데모 모드입니다. 롤백은 실행되지 않습니다 (API 연동 전).');
  }

  void _onResolve(String name) {
    _snack('데모 모드입니다. "$name" 불일치는 실제로 해결되지 않습니다 (API 연동 전).');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          const MockDemoBanner(),
          const SizedBox(height: AppSpacing.lg),
          _statusRow(),
          const SizedBox(height: AppSpacing.lg),
          _IntegrityCard(onResolve: _onResolve),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('데이터 동기화 · 무결성 제어', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '고용24 기록과 Zoom 출결 로그 간 동기화를 관리합니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            AppButton(
              label: '롤백',
              icon: Icons.undo_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _onRollback,
            ),
            AppButton(
              label: '교차 검증 실행',
              icon: Icons.sync,
              loading: _mockRunning,
              onPressed: _onRunCrossCheck,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusRow() {
    const cards = <Widget>[
      // MOCK: last successful sync timestamp.
      StatCard(
        label: '마지막 동기화',
        value: '오늘 09:30',
        icon: Icons.update_outlined,
        delta: '정상 완료',
      ),
      // MOCK: number of detected data mismatches.
      StatCard(
        label: '데이터 불일치',
        value: '3건',
        icon: Icons.warning_amber_outlined,
        delta: '확인 필요',
        deltaPositive: false,
      ),
      // MOCK: total records cross-checked this cycle.
      StatCard(
        label: '검증 레코드',
        value: '150건',
        icon: Icons.fact_check_outlined,
        delta: '이번 주기',
      ),
    ];

    return ResponsiveLayout(
      mobile: (_) => const _StatGrid(crossAxisCount: 1, children: cards),
      tablet: (_) => const _StatGrid(crossAxisCount: 3, children: cards),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.crossAxisCount, required this.children});

  final int crossAxisCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalGutter = AppSpacing.gutter * (crossAxisCount - 1);
        final tileWidth =
            (constraints.maxWidth - totalGutter) / crossAxisCount;
        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Integrity cross-check table
/// ───────────────────────────────────────────────────────────────────────────

class _IntegrityCard extends StatelessWidget {
  const _IntegrityCard({required this.onResolve});

  final void Function(String studentName) onResolve;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '데이터 무결성 교차 검증',
      icon: Icons.fact_check_outlined,
      child: AppDataTable(
        columns: const ['수강생', '날짜', '고용24', 'Zoom', '상태', '작업'],
        columnFlex: const [3, 3, 2, 2, 2, 2],
        rows: [
          for (final r in _mockChecks)
            AppTableRow(
              highlight: !r.matched,
              cells: [
                Text(r.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(r.date,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                Text(
                  r.goyong,
                  style: AppTypography.bodySm.copyWith(
                    color: r.matched ? AppColors.onSurface : AppColors.error,
                    fontWeight: r.matched ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                Text(r.zoom,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: r.matched ? '일치' : '불일치',
                    tone: r.matched ? StatusTone.success : StatusTone.danger,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: r.matched
                      ? const Icon(Icons.check_circle_outline,
                          size: 18, color: AppColors.primary)
                      : AppButton(
                          label: '해결',
                          variant: AppButtonVariant.tertiary,
                          onPressed: () => onResolve(r.name),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Mock model + data
/// ───────────────────────────────────────────────────────────────────────────

typedef _IntegrityCheck = ({
  String name,
  String date,
  String goyong,
  String zoom,
  bool matched,
});

// MOCK: integrity cross-check rows. No `/sync/integrity` endpoint yet.
const _mockChecks = <_IntegrityCheck>[
  (name: '김민수', date: '2026-05-28', goyong: '08:55', zoom: '08:54', matched: true),
  (name: '이지은', date: '2026-05-28', goyong: '09:00', zoom: '09:15', matched: false),
  (name: '박준영', date: '2026-05-28', goyong: '08:50', zoom: '08:48', matched: true),
  (name: '최서연', date: '2026-05-28', goyong: '09:05', zoom: '—', matched: false),
];

// ── REPOSITORY SEAM ──────────────────────────────────────────────────────────
// TODO(backend): replace the `_mock*` data + the no-op handlers with a real
// sync repository once endpoints exist, e.g.:
//
//   final repo = DataSyncRepository(dio);
//   final status = await repo.getStatus();         // GET /sync/status
//   final checks = await repo.getIntegrity();      // GET /sync/integrity
//   await repo.run();                               // POST /sync/run
//   await repo.rollback(batchId);                   // POST /sync/{batch}/rollback
//
// Drive job state through a Riverpod AsyncNotifier; keep the confirmation
// dialogs for the destructive run/rollback actions and surface 422 business
// errors via ApiErrorMessages.
