import 'dart:ui';

import 'oklch.dart';

/// Design tokens lifted verbatim (same OKLCH values) from the Vela Claude
/// Design source. Screens choose which surface (ink/dark vs paper/light) to
/// sit on explicitly, matching the mockups - this is not a single global
/// light/dark palette swap.
abstract final class AppColors {
  // Dark ("ink") surfaces
  static final Color ink900 = oklch(0.17, 0.012, 265);
  static final Color ink850 = oklch(0.195, 0.013, 265);
  static final Color ink800 = oklch(0.22, 0.014, 265);
  static final Color ink700 = oklch(0.27, 0.015, 265);
  static final Color hairlineDark = oklch(1.0, 0, 0, 0.09);
  static final Color onDark = oklch(0.97, 0.004, 265);
  static final Color onDarkMuted = oklch(0.73, 0.014, 265);
  static final Color onDarkFaint = oklch(0.56, 0.015, 265);

  // Light ("paper") surfaces
  static final Color paper = oklch(0.976, 0.004, 265);
  static final Color card = oklch(1.0, 0, 0);
  static final Color hairlineLight = oklch(0.92, 0.006, 265);
  static final Color onLight = oklch(0.21, 0.015, 265);
  static final Color onLightMuted = oklch(0.50, 0.015, 265);
  static final Color onLightFaint = oklch(0.66, 0.012, 265);

  // Accent (mint/green) - brand, positive, "money kept"
  static final Color accent = oklch(0.85, 0.17, 148);
  static final Color accentDim = oklch(0.62, 0.13, 150);
  static final Color accentInk = oklch(0.26, 0.07, 150);
  static final Color accentTint = oklch(0.94, 0.05, 148);

  // Category / semantic colors
  static final Color violet = oklch(0.72, 0.13, 292);
  static final Color sky = oklch(0.76, 0.11, 238);
  static final Color amber = oklch(0.82, 0.13, 80);
  static final Color rose = oklch(0.69, 0.15, 15);
  /// Gradient end-stop for the Overview flow bar's outflow segment
  /// (`linear-gradient(90deg, rose, this)` in the mock) - not a reused
  /// token elsewhere, just this one bar.
  static final Color roseFlowGradientEnd = oklch(0.72, 0.13, 30);
  static final Color amberTint = oklch(0.95, 0.04, 80);
  static final Color roseTint = oklch(0.95, 0.035, 15);

  // Ink-on-tint pairs (avatars, chips, banners)
  static final Color amberInk = oklch(0.45, 0.1, 70);
  static final Color amberTextOnTint = oklch(0.38, 0.09, 70);
  static final Color violetInk = oklch(0.38, 0.1, 292);
  static final Color violetTint = oklch(0.95, 0.02, 292);
  static final Color skyInk = oklch(0.38, 0.09, 238);
  static final Color skyTint = oklch(0.95, 0.02, 238);
  static final Color roseInk = oklch(0.40, 0.12, 15);
  static final Color roseAvatarTint = oklch(0.95, 0.03, 15);

  // Misc surfaces
  static final Color progressTrackLight = oklch(0.93, 0.006, 265);
  static final Color skeletonBase = oklch(0.94, 0.005, 265);
  static final Color skeletonHighlight = oklch(0.96, 0.004, 265);
  static final Color skeletonBaseDark = oklch(0.24, 0.014, 265);
  static final Color skeletonHighlightDark = oklch(0.30, 0.015, 265);
  static final Color analysingGlowCenter = oklch(0.24, 0.04, 155);
  static final Color scrimHeavy = oklch(0.10, 0.01, 265, 0.72);
  static final Color scrimMedium = oklch(0.20, 0.01, 265, 0.35);

  /// Category name -> brand color. The mock only illustrates Food/Travel/
  /// Bills/Shopping/Personal Care/Income; the backend's full taxonomy (see
  /// transaction_sheet.dart's category list) has more, so every real
  /// category gets an explicit, non-alarming hue here - rose is reserved for
  /// truly unrecognized/uncategorized spend, not "not in the mock".
  static Color forCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return accentDim;
      case 'travel':
        return violet;
      case 'bills':
        return amber;
      case 'shopping':
        return sky;
      case 'personal care':
        return violet;
      case 'income':
        return accent;
      case 'entertainment':
        return sky;
      case 'friends':
        return accentDim;
      case 'education':
        return violet;
      case 'healthcare':
        return amber;
      case 'subscription':
        return sky;
      case 'utility':
        return amber;
      default:
        return rose;
    }
  }
}
