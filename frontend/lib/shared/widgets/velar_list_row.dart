import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'avatar_chip.dart';
import 'micro_badge.dart';

/// Generic row: avatar + 2-line text block + trailing amount + optional
/// badge. Backs merchant rows, transaction rows, and subscription headers.
class VelaListRow extends StatelessWidget {
  const VelaListRow({
    super.key,
    required this.avatarInitials,
    required this.avatarTint,
    required this.avatarInk,
    required this.title,
    required this.subtitle,
    required this.trailingAmount,
    this.trailingAmountColor,
    this.badgeLabel,
    this.onTap,
    this.dark = false,
    this.avatarGradient,
  });

  final String avatarInitials;
  final Color avatarTint;
  final Color avatarInk;
  final Gradient? avatarGradient;
  final String title;
  final String subtitle;
  final String trailingAmount;
  final Color? trailingAmountColor;
  final String? badgeLabel;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final onSurface = dark ? AppColors.onDark : AppColors.onLight;
    final onSurfaceFaint = dark ? AppColors.onDarkFaint : AppColors.onLightFaint;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            AvatarChip(
              initials: avatarInitials,
              size: 38,
              radius: 12,
              backgroundColor: avatarTint,
              foregroundColor: avatarInk,
              gradient: avatarGradient,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTypography.rowLabel145.copyWith(color: onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.meta115.copyWith(color: onSurfaceFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trailingAmount, style: AppTypography.amountMedium15.copyWith(color: trailingAmountColor ?? onSurface)),
                if (badgeLabel != null) ...[
                  const SizedBox(height: 4),
                  MicroBadge(label: badgeLabel!, tint: AppColors.amberTint, foreground: AppColors.amberInk),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
