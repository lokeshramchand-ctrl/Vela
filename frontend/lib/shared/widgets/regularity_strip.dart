import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum RegularitySegmentState { paid, skipped, upcoming }

/// Recurring-payment "rhythm strip": 7 rounded month segments - filled when
/// paid on schedule, lighter when a payment was skipped, dashed outline
/// when upcoming/projected.
class RegularityStrip extends StatelessWidget {
  const RegularityStrip({
    super.key,
    required this.states,
    required this.color,
    required this.startLabel,
    required this.endLabel,
    required this.centerLabel,
  });

  final List<RegularitySegmentState> states;
  final Color color;
  final String startLabel;
  final String endLabel;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final state in states) ...[
              Expanded(child: _segment(state)),
              if (state != states.last) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(startLabel, style: AppTypography.meta115.copyWith(color: AppColors.onLightFaint)),
            Text(centerLabel, style: AppTypography.meta115.copyWith(color: AppColors.onLightFaint)),
            Text(endLabel, style: AppTypography.meta115.copyWith(color: AppColors.onLightFaint)),
          ],
        ),
      ],
    );
  }

  Widget _segment(RegularitySegmentState state) {
    return switch (state) {
      RegularitySegmentState.paid => Container(
          height: 22,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
        ),
      RegularitySegmentState.skipped => Container(
          height: 22,
          decoration: BoxDecoration(color: AppColors.skeletonHighlight, borderRadius: BorderRadius.circular(6)),
        ),
      RegularitySegmentState.upcoming => Container(
          height: 22,
          decoration: BoxDecoration(
            border: Border.all(color: color, style: BorderStyle.solid, width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
    };
  }
}
