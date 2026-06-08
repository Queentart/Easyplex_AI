import 'package:flutter/material.dart';

/// Elevation tokens — depth via soft ambient shadows, not hard borders.
///
/// Source of truth: Stitch `DESIGN.md` elevation section.
///   L1 cards     : 0 2px 4px rgba(0,0,0,0.05)
///   L2 hover     : 0 4px 8px rgba(0,0,0,0.08)
///   L3 overlays  : 0 10px 25px rgba(0,0,0,0.10)
class AppShadows {
  AppShadows._();

  /// Level 1 — resting cards / containers.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000), // black @ 5%
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Level 2 — hovered / lifted cards.
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x14000000), // black @ 8%
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];

  /// Level 3 — modals, dropdowns, popovers.
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x1A000000), // black @ 10%
      offset: Offset(0, 10),
      blurRadius: 25,
    ),
  ];
}
