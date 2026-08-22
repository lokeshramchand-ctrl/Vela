import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// "SIGNALS ... All 5 →" style row: tracked mono micro-label with an
/// optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, required this.labelColor, this.trailing});

  final String label;
  final Color labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.microLabelTracked11.copyWith(color: labelColor)),
        ?trailing,
      ],
    );
  }
}
