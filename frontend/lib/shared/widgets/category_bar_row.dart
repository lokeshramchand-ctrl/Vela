import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A ranked category row: name+amount header, then a track+fill bar (width
/// relative to the largest category, not an absolute percentage-of-total),
/// a %, and an optional trend caption below.
class CategoryBarRow extends StatelessWidget {
  const CategoryBarRow({
    super.key,
    required this.name,
    required this.amountLabel,
    required this.percentOfTotal,
    required this.relativeWidthFraction,
    required this.color,
    this.trendCaption,
    this.onTap,
  });

  final String name;
  final String amountLabel;
  final int percentOfTotal;
  final double relativeWidthFraction; // 0-1, relative to the largest category
  final Color color;
  final String? trendCaption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowLabel14.copyWith(color: AppColors.onLight),
                  ),
                ),
                const SizedBox(width: 8),
                Text(amountLabel, style: AppTypography.amountMedium14.copyWith(color: AppColors.onLight)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 7,
                      color: AppColors.progressTrackLight,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: relativeWidthFraction.clamp(0, 1),
                        child: Container(color: color)
                            .animate()
                            .scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: 420.ms, curve: const Cubic(0.2, 0.8, 0.2, 1)),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$percentOfTotal%',
                    textAlign: TextAlign.right,
                    style: AppTypography.microLabel11.copyWith(color: AppColors.onLightMuted),
                  ),
                ),
              ],
            ),
            if (trendCaption != null) ...[
              const SizedBox(height: 4),
              Text(trendCaption!, style: AppTypography.footnote1155.copyWith(color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
