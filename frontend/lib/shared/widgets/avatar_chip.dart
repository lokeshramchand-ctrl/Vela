import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// Circular/squircle initials avatar. Used for the user's own avatar
/// (gradient accent fill) and for merchant avatars (flat tint/ink pair).
class AvatarChip extends StatelessWidget {
  const AvatarChip({
    super.key,
    required this.initials,
    this.size = 40,
    this.radius,
    this.backgroundColor,
    this.foregroundColor,
    this.gradient,
  });

  final String initials;
  final double size;
  final double? radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final fontSize = size * 0.36;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? Theme.of(context).colorScheme.primary) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius ?? size / 2),
      ),
      child: Text(
        initials,
        style: AppTypography.amountMedium14.copyWith(
          fontSize: fontSize,
          color: foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
