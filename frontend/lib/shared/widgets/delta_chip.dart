import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// Pill: tinted background + colored text carrying its own direction glyph,
/// e.g. "▲ 12%" - matches the mock, which renders this as a single text
/// node rather than an icon+label pair.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.label,
    required this.up,
    required this.tint,
    required this.foreground,
  });

  /// Includes its own arrow glyph (e.g. "▲ 12%"), rendered as-is.
  final String label;

  /// Not rendered directly (the glyph in [label] already carries direction);
  /// used only to give screen readers a spoken direction independent of the
  /// glyph, since amount color/arrows must never be the only signal.
  final bool up;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${up ? 'Increased' : 'Decreased'} $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadius.chip)),
        child: Text(label, style: AppTypography.buttonLabel12.copyWith(color: foreground)),
      ),
    );
  }
}
