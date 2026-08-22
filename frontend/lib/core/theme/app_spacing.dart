/// Spacing scale: 4 · 8 · 12 · 16 · 22 · 26 · 32. Screen gutter is 22.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double gutter = 22;
  static const double lg = 26;
  static const double xl = 32;

  /// Bottom scroll-content clearance for the three AppShell tab bodies, so
  /// content doesn't render behind the floating pill nav.
  static const double navClearance = 108;
}
