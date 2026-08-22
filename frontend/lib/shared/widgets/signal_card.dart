import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../features/statements/domain/insight.dart';
import 'app_buttons.dart';

enum SignalKind { watch, good, context }

extension SignalKindFromSeverity on InsightSeverity {
  SignalKind get signalKind => switch (this) {
        InsightSeverity.warning => SignalKind.watch,
        InsightSeverity.positive => SignalKind.good,
        InsightSeverity.info => SignalKind.context,
      };
}

/// A ranked, typed insight card - the design's core "signal" primitive,
/// used on both Overview (preview) and Signals (full list).
class SignalCard extends StatelessWidget {
  const SignalCard({
    super.key,
    required this.kind,
    required this.subtype,
    required this.body,
    this.evidence,
    this.ctaLabel,
    this.onCta,
    this.dark = true,
    this.entranceDelayMs = 0,
  });

  final SignalKind kind;
  final String subtype;
  final String body;
  final String? evidence;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool dark;
  final int entranceDelayMs;

  (Color tint, Color ink, String label, IconData icon) get _style => switch (kind) {
        SignalKind.watch => (AppColors.amber.withValues(alpha: 0.2), AppColors.amber, 'WATCH', Icons.priority_high_rounded),
        SignalKind.good => (AppColors.accent.withValues(alpha: 0.2), AppColors.accent, 'GOOD', Icons.check_rounded),
        SignalKind.context => (AppColors.sky.withValues(alpha: 0.2), AppColors.sky, 'CONTEXT', Icons.info_outline_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (tint, ink, label, icon) = _style;
    final card = Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink850 : AppColors.card,
        border: Border.all(color: dark ? AppColors.hairlineDark : AppColors.hairlineLight),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: ink),
              ),
              const SizedBox(width: 8),
              Text(label, style: AppTypography.microLabelTracked105.copyWith(color: ink)),
              const Spacer(),
              Flexible(
                child: Text(
                  subtype,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.microLabel11.copyWith(color: dark ? AppColors.onDarkFaint : AppColors.onLightFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: AppTypography.cardBody15.copyWith(color: dark ? AppColors.onDark : AppColors.onLight)),
          if (evidence != null || ctaLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.ink800 : AppColors.paper,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Row(
                children: [
                  if (evidence != null)
                    Expanded(
                      child: Text(
                        evidence!,
                        style: AppTypography.meta115.copyWith(color: dark ? AppColors.onDarkMuted : AppColors.onLightMuted),
                      ),
                    ),
                  if (ctaLabel != null && onCta != null) TextActionLink(label: ctaLabel!, onPressed: onCta!, color: AppColors.accent),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return card
        .animate(delay: entranceDelayMs.ms)
        .fadeIn(duration: 240.ms)
        .moveY(begin: 6, end: 0, duration: 240.ms, curve: Curves.easeOut);
  }
}
