import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/shared/widgets/app_button.dart';

/// Objective height verification for the community post-list toolbar.
///
/// The bug: in `post_list_screen.dart` the search [TextField] and the
/// `글쓰기` [AppButton] should have the SAME visible height, but the green
/// button paints SHORTER than the field.
///
/// Root cause (proved by [_buttonFillHeight] in the un-stretched cases below):
/// a [FilledButton] with the default [MaterialTapTargetSize.padded] reserves a
/// 48px tap slot but paints its coloured [Material] at its ~40px *preferred*
/// height, centred in that slot. So the visible fill is 8px short of the 48px
/// field. The old `dense` style only set `minimumSize: Size(0, infinity)`,
/// which is unsatisfiable and clamped away — it did nothing on its own and only
/// "worked" when a tight `SizedBox(height:48)` + `stretch` parent dragged the
/// fill up. The fix makes `dense` set `tapTargetSize.shrinkWrap` +
/// `minimumSize: Size(0, 48)` so the coloured fill reaches 48 by itself.

/// Visible field height = the [InputDecorator] (it paints the filled box).
double _fieldHeight(WidgetTester tester) => tester
    .getSize(find.descendant(
        of: find.byType(TextField), matching: find.byType(InputDecorator)))
    .height;

/// Visible button height = the coloured [Material] painted inside the
/// [FilledButton] (this is the green box the user actually sees; with
/// `tapTargetSize.padded` it is smaller than the 48px tap slot).
double _buttonFillHeight(WidgetTester tester) => tester
    .getSize(find
        .descendant(
            of: find.byType(FilledButton), matching: find.byType(Material))
        .first)
    .height;

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light, // real production theme (Input + FilledButton)
      home: Scaffold(body: Center(child: child)),
    );

/// The EXACT toolbar from post_list_screen.dart.
Widget _toolbarRow({required bool dense}) => SizedBox(
      width: 600,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '제목·내용 검색',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: '글쓰기',
              icon: Icons.edit_outlined,
              variant: AppButtonVariant.primary,
              dense: dense,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('toolbar: field and 글쓰기 button visible heights are equal',
      (tester) async {
    await tester.pumpWidget(_wrap(_toolbarRow(dense: true)));
    await tester.pumpAndSettle();

    final fieldH = _fieldHeight(tester);
    final btnH = _buttonFillHeight(tester);
    // ignore: avoid_print
    print('TOOLBAR field=$fieldH btn=$btnH');
    expect((fieldH - btnH).abs(), lessThan(1.0),
        reason: 'field=$fieldH btn=$btnH');
  });

  // This is the test that FAILS without the fix and PASSES with it. It isolates
  // the button so no tight parent constraint can mask the collapse: the coloured
  // fill must reach 48 purely from `AppButton.dense`'s own style.
  testWidgets('dense button coloured fill reaches 48 on its own (root-cause)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: '글쓰기',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.primary,
            dense: true,
            onPressed: () {},
          ),
        ],
      )),
    );
    await tester.pumpAndSettle();

    const fieldNatural = 48.0; // theme InputDecorator natural height
    final btnH = _buttonFillHeight(tester);
    // ignore: avoid_print
    print('ROOT-CAUSE dense-fill=$btnH (target=$fieldNatural)');
    expect((btnH - fieldNatural).abs(), lessThan(1.0),
        reason: 'dense fill should be 48 on its own, got $btnH');
  });

  // Pins the documented root cause: the NON-dense button collapses to ~40 when
  // not height-constrained, and the field's natural height is 48 — an 8px gap.
  testWidgets('root cause: stock button=40 vs field=48 when unconstrained',
      (tester) async {
    await tester.pumpWidget(
      _wrap(AppButton(
        label: '글쓰기',
        icon: Icons.edit_outlined,
        variant: AppButtonVariant.primary,
        onPressed: () {},
      )),
    );
    await tester.pumpAndSettle();
    final stockFill = _buttonFillHeight(tester);
    // ignore: avoid_print
    print('ROOT-CAUSE stock-fill=$stockFill');

    await tester.pumpWidget(
      _wrap(SizedBox(
        width: 400,
        child: TextField(
          decoration: const InputDecoration(
            isDense: true,
            hintText: '제목·내용 검색',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      )),
    );
    await tester.pumpAndSettle();
    final fieldNatural = tester.getSize(find.byType(InputDecorator)).height;
    // ignore: avoid_print
    print('ROOT-CAUSE field-natural=$fieldNatural');

    expect(stockFill, closeTo(40.0, 0.5));
    expect(fieldNatural, closeTo(48.0, 0.5));
  });
}
