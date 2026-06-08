import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A single row of cells for [AppDataTable]. [highlight] tints at-risk rows.
class AppTableRow {
  const AppTableRow({required this.cells, this.highlight = false});

  final List<Widget> cells;
  final bool highlight;
}

/// Table styled to the mockups:
///  - taupe (secondary-container) header with small-caps label-sm
///  - subtle 1px horizontal dividers, no vertical lines
///  - pale-sand hover highlight, no zebra striping
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnFlex,
  });

  final List<String> columns;
  final List<AppTableRow> rows;

  /// Optional flex weight per column (defaults to 1 each).
  final List<int>? columnFlex;

  int _flex(int i) =>
      (columnFlex != null && i < columnFlex!.length) ? columnFlex![i] : 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: AppColors.secondaryContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: _flex(i),
                    child: Text(
                      columns[i].toUpperCase(),
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Rows
          for (var r = 0; r < rows.length; r++)
            _HoverRow(
              highlight: rows[r].highlight,
              showDivider: r != rows.length - 1,
              child: Row(
                children: [
                  for (var i = 0; i < rows[r].cells.length; i++)
                    Expanded(
                      flex: _flex(i),
                      child: DefaultTextStyle.merge(
                        style: AppTypography.bodySm,
                        child: rows[r].cells[i],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({
    required this.child,
    required this.highlight,
    required this.showDivider,
  });

  final Widget child;
  final bool highlight;
  final bool showDivider;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = _hovered
        ? AppColors.paleSand
        : widget.highlight
            ? AppColors.errorContainer.withValues(alpha: 0.2)
            : AppColors.surfaceContainerLowest;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          border: widget.showDivider
              ? const Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: widget.child,
      ),
    );
  }
}
