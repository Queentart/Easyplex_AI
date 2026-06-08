/// Spacing, radius and breakpoint tokens.
///
/// Source of truth: Stitch `DESIGN.md` (8pt grid, 4px base increments).
class AppSpacing {
  AppSpacing._();

  static const double base = 4;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

  /// Outer page margin on desktop / tablet.
  static const double containerMargin = 24;

  /// Grid gutter between columns.
  static const double gutter = 16;
}

/// Corner radius tokens.
///
/// Controls (buttons, inputs) stay precise at [md]; containers (cards, modals)
/// use the softer [lg] / [xl] to read as friendly-but-professional.
class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double base = 8;
  static const double md = 8; // controls: buttons, inputs, chips
  static const double lg = 16; // cards
  static const double xl = 24; // hero cards, modals
  static const double full = 9999;
}

/// Responsive breakpoints (logical pixels).
///
/// Desktop 1440px+ → 12 col. Tablet 768–1024px → 8 col, sidebar→drawer.
/// Mobile <768px → 4 col.
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 768;
  static const double tablet = 1024;
  static const double desktop = 1440;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}
