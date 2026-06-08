import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cohort_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Global cohort dropdown shown at the top of the nav (instructor / operations).
///
/// Sets [selectedCohortProvider] — the 1st-level cohort filter that cohort-scoped
/// screens read as their default. "기수 전체" (value `null`) is the default and is
/// always the first option.
class CohortSelector extends ConsumerWidget {
  const CohortSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCohortProvider);
    final optionsAsync = ref.watch(cohortOptionsProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기수 선택',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          optionsAsync.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Text(
              '기수 목록을 불러오지 못했습니다',
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
            data: (options) {
              return DropdownButtonFormField<int?>(
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('기수 전체'),
                  ),
                  for (final o in options)
                    DropdownMenuItem<int?>(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) =>
                    ref.read(selectedCohortProvider.notifier).select(v),
              );
            },
          ),
        ],
      ),
    );
  }
}
