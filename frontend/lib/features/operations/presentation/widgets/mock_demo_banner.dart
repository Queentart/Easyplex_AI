import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/status_chip.dart';

/// Reusable "데모 데이터" banner shown on every operations monitoring screen.
///
/// All four ops monitoring screens (system status / server logs / system
/// settings / data sync) are MOCK-ONLY: there is no `/system/*` backend yet
/// (see study/memo/0529/mockup_backend_gap_analysis.md §1). This banner makes
/// the mock nature unmistakable to the viewer.
class MockDemoBanner extends StatelessWidget {
  const MockDemoBanner({
    super.key,
    this.caption = '실시간 모니터링 API 연동 전 예시 데이터입니다.',
  });

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.onWarningContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              caption,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onWarningContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const StatusChip(label: '데모 데이터', tone: StatusTone.warning),
        ],
      ),
    );
  }
}
