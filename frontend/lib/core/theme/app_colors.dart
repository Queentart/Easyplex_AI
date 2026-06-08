import 'package:flutter/material.dart';

/// Canonical color tokens for the DongA AI Lab Education Operations Platform.
///
/// Source of truth: Stitch `DESIGN.md` frontmatter (Material 3 export).
/// The "warm minimalist / academic-humanist" look in the mockups is fully
/// expressible through these tokens — e.g. the muted-taupe table header is
/// [secondaryContainer], the pale-sand hover is [paleSand]. Do NOT introduce
/// the prototype-only inline overrides (#F5F5F0 / #0D9488); use these instead.
class AppColors {
  AppColors._();

  // ── Surfaces ──────────────────────────────────────────────────────────
  static const surface = Color(0xFFF9F9FF);
  static const surfaceDim = Color(0xFFD0DAEF);
  static const surfaceBright = Color(0xFFF9F9FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF3FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceContainerHigh = Color(0xFFDEE9FD);
  static const surfaceContainerHighest = Color(0xFFD9E3F7);
  static const surfaceVariant = Color(0xFFD9E3F7);

  // ── On-surface / text ─────────────────────────────────────────────────
  static const onSurface = Color(0xFF121C2A);
  static const onSurfaceVariant = Color(0xFF3D4947);
  static const inverseSurface = Color(0xFF273140);
  static const inverseOnSurface = Color(0xFFEBF1FF);

  // ── Outlines ──────────────────────────────────────────────────────────
  static const outline = Color(0xFF6D7A77);
  static const outlineVariant = Color(0xFFBCC9C6);

  // ── Primary (teal green) ──────────────────────────────────────────────
  static const surfaceTint = Color(0xFF006A61);
  static const primary = Color(0xFF00685F);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF008378);
  static const onPrimaryContainer = Color(0xFFF4FFFC);
  static const inversePrimary = Color(0xFF6BD8CB);
  static const primaryFixed = Color(0xFF89F5E7);
  static const primaryFixedDim = Color(0xFF6BD8CB);
  static const onPrimaryFixed = Color(0xFF00201D);
  static const onPrimaryFixedVariant = Color(0xFF005049);

  // ── Secondary (warm taupe) ────────────────────────────────────────────
  static const secondary = Color(0xFF625E55);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE8E2D6); // == "muted taupe"
  static const onSecondaryContainer = Color(0xFF68645B);
  static const secondaryFixed = Color(0xFFE8E2D6);
  static const secondaryFixedDim = Color(0xFFCBC6BA);
  static const onSecondaryFixed = Color(0xFF1E1C14);
  static const onSecondaryFixedVariant = Color(0xFF4A473E);

  // ── Tertiary ──────────────────────────────────────────────────────────
  static const tertiary = Color(0xFF006860);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF248279);
  static const onTertiaryContainer = Color(0xFFF3FFFC);
  static const tertiaryFixed = Color(0xFF9CF2E8);
  static const tertiaryFixedDim = Color(0xFF80D5CB);
  static const onTertiaryFixed = Color(0xFF00201D);
  static const onTertiaryFixedVariant = Color(0xFF00504A);

  // ── Error ─────────────────────────────────────────────────────────────
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // ── Semantic status (derived; used by status chips / dashboards) ───────
  static const success = Color(0xFF00685F); // reuse primary teal for "ok/normal"
  static const warning = Color(0xFF8A5A00);
  static const warningContainer = Color(0xFFFFDDB3);
  static const onWarningContainer = Color(0xFF2C1700);

  // ── Component helpers ─────────────────────────────────────────────────
  /// Pale-sand hover tint used across cards, rows and list items.
  static const paleSand = Color(0xFFFAF9F6);

  /// Background for the overall scaffold canvas.
  static const background = surface;
}
