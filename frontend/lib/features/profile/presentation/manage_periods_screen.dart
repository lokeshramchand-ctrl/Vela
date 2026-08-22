import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/feature_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/screen_back_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../statements/domain/statement.dart';
import '../../statements/presentation/period_providers.dart';

class ManagePeriodsScreen extends ConsumerWidget {
  const ManagePeriodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(periodsProvider);

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, 0),
              child: ScreenBackHeader(title: 'Manage periods'),
            ),
            Expanded(
              child: periodsAsync.when(
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => const SkeletonBox(width: double.infinity, height: 68, radius: AppRadius.card, dark: true),
                ),
                error: (e, _) => ErrorRetry(dark: true, message: 'Could not load periods.', onRetry: () => ref.invalidate(periodsProvider)),
                data: (periods) {
                  if (periods.isEmpty) {
                    return const EmptyState(
                      dark: true,
                      icon: Icons.folder_open_outlined,
                      title: 'No periods yet',
                      subtitle: 'Statements you add will show up here.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    itemCount: periods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _PeriodTile(period: periods[index], entranceDelayMs: index.clamp(0, 6) * 40),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTile extends ConsumerStatefulWidget {
  const _PeriodTile({required this.period, this.entranceDelayMs = 0});
  final Statement period;
  final int entranceDelayMs;

  @override
  ConsumerState<_PeriodTile> createState() => _PeriodTileState();
}

class _PeriodTileState extends ConsumerState<_PeriodTile> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.ink850, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatPeriodRange(period.periodStart, period.periodEnd), style: AppTypography.rowLabel145.copyWith(color: AppColors.onDark)),
                const SizedBox(height: 4),
                Text('${period.originalFilename} · ${period.transactionCount} txns', style: AppTypography.meta115.copyWith(color: AppColors.onDarkFaint)),
              ],
            ),
          ),
          if (_deleting)
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))
          else
            IconButton(
              tooltip: 'Delete ${formatPeriodRange(period.periodStart, period.periodEnd)}',
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 20),
              onPressed: _confirmDelete,
            ),
        ],
      ),
    );

    return card
        .animate(delay: widget.entranceDelayMs.ms)
        .fadeIn(duration: 220.ms)
        .moveY(begin: 6, end: 0, duration: 220.ms, curve: Curves.easeOut);
  }

  Future<void> _confirmDelete() async {
    final period = widget.period;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink850,
        title: Text('Delete this period?', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
        content: Text(
          'This permanently deletes ${period.originalFilename} and all ${period.transactionCount} of its transactions. This cannot be undone.',
          style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: TextStyle(color: AppColors.onDarkMuted))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete', style: TextStyle(color: AppColors.rose))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(statementsRepositoryProvider).delete(period.id);
      ref.invalidate(periodsProvider);
      messenger.showSnackBar(SnackBar(content: Text('${period.originalFilename} deleted'), backgroundColor: AppColors.ink700));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.rose));
    }
  }
}
