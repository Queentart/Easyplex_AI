import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Chooses a builder based on the current width using [AppBreakpoints].
///
///   - width <  768           → [mobile]
///   - 768 ≤ width < 1440      → [tablet] (falls back to [desktop] then [mobile])
///   - width ≥ 1440            → [desktop] (falls back to [tablet] then [mobile])
///
/// Only [mobile] is required; the others gracefully degrade.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  static bool isMobile(BuildContext context) =>
      AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);

  static bool isTablet(BuildContext context) =>
      AppBreakpoints.isTablet(MediaQuery.sizeOf(context).width);

  static bool isDesktop(BuildContext context) =>
      AppBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (AppBreakpoints.isDesktop(width)) {
          return (desktop ?? tablet ?? mobile)(context);
        }
        if (AppBreakpoints.isTablet(width)) {
          return (tablet ?? desktop ?? mobile)(context);
        }
        return mobile(context);
      },
    );
  }
}
