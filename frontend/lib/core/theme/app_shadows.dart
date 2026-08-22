import 'package:flutter/widgets.dart';

import 'oklch.dart';

/// Elevation is expressed as explicit shadow lists, not Material's elevation
/// int, because the design's dark surfaces use hairlines only - never
/// shadows - while light surfaces use soft, wide-spread card shadows.
abstract final class AppShadows {
  static final List<BoxShadow> flat = [
    BoxShadow(color: oklch(0, 0, 0, 0.05), offset: const Offset(0, 1), blurRadius: 2),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(color: oklch(0, 0, 0, 0.04), offset: const Offset(0, 1), blurRadius: 2),
    BoxShadow(color: oklch(0, 0, 0, 0.18), offset: const Offset(0, 14), blurRadius: 30, spreadRadius: -18),
  ];

  static final List<BoxShadow> sheetLight = [
    BoxShadow(color: oklch(0, 0, 0, 0.35), offset: const Offset(0, -20), blurRadius: 60, spreadRadius: -20),
  ];

  static final List<BoxShadow> floatingNav = [
    BoxShadow(color: oklch(0, 0, 0, 0.5), offset: const Offset(0, 18), blurRadius: 40, spreadRadius: -14),
  ];

  static final List<BoxShadow> none = const [];
}
