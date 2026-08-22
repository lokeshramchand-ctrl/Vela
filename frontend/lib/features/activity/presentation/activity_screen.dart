import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/Vela_list_row.dart';
import '../../statements/domain/statement.dart';
import '../../statements/domain/transaction.dart';
import '../../statements/presentation/period_providers.dart';
import 'activity_controller.dart';
import 'transaction_sheet.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 400) {
        ref.read(activityControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityControllerProvider);
    final period = ref.watch(currentPeriodProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _StickyHeader(searchController: _searchController, period: period),
            Expanded(
              child: activityAsync.when(
                loading: () => ListView.builder(
                  padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, AppSpacing.navClearance + MediaQuery.of(context).padding.bottom),
                  itemCount: 8,
                  itemBuilder: (context, index) => const SkeletonListRow(),
                ),
                error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(activityControllerProvider)),
                data: (state) {
                  if (period == null) return const SizedBox.shrink();
                  if (state.transactions.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No transactions match these filters',
                      subtitle: 'Try clearing the search or filter chips above.',
                    );
                  }
                  final groups = _groupByDay(state.transactions);
                  return RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: () => ref.refresh(activityControllerProvider.future),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, AppSpacing.navClearance + MediaQuery.of(context).padding.bottom),
                      itemCount: groups.length + (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= groups.length) return const SkeletonListRow();
                        final group = groups[index];
                        final dayTotal = group.transactions.fold<double>(0, (sum, t) => sum + (t.transactionType == TransactionType.debit ? -t.amount : t.amount));
                        final column = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(formatDayHeader(group.day), style: AppTypography.microLabelTracked11.copyWith(color: AppColors.onLightFaint)),
                                  Text(
                                    formatCurrency(dayTotal, forceSign: dayTotal > 0),
                                    style: AppTypography.microLabelTracked11.copyWith(color: dayTotal > 0 ? AppColors.accentDim : AppColors.onLightFaint),
                                  ),
                                ],
                              ),
                            ),
                            for (final txn in group.transactions)
                              VelaListRow(
                                avatarInitials: (txn.merchant?.isNotEmpty ?? false) ? txn.merchant![0].toUpperCase() : '?',
                                avatarTint: AppColors.forCategory(txn.category ?? '').withValues(alpha: 0.16),
                                avatarInk: AppColors.forCategory(txn.category ?? ''),
                                title: txn.merchant ?? 'Unknown merchant',
                                subtitle: '${formatTime12h(txn.timestamp)} · ${(txn.category ?? 'UNCATEGORIZED').toUpperCase()}',
                                trailingAmount: '${txn.transactionType == TransactionType.debit ? '−' : '+'}${formatCurrency(txn.amount.abs())}',
                                trailingAmountColor: txn.transactionType == TransactionType.credit ? AppColors.accentDim : null,
                                badgeLabel: txn.status != TransactionStatus.success ? txn.status.name.toUpperCase() : null,
                                onTap: () => showTransactionSheet(context, txn),
                              ),
                          ],
                        );
                        return column
                            .animate(delay: (index.clamp(0, 6) * 40).ms)
                            .fadeIn(duration: 220.ms)
                            .moveY(begin: 6, end: 0, duration: 220.ms, curve: Curves.easeOut);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<Transaction> transactions) {
    final groups = <_DayGroup>[];
    for (final txn in transactions) {
      final day = DateTime(txn.timestamp.year, txn.timestamp.month, txn.timestamp.day);
      if (groups.isNotEmpty && groups.last.day == day) {
        groups.last.transactions.add(txn);
      } else {
        groups.add(_DayGroup(day: day, transactions: [txn]));
      }
    }
    return groups;
  }
}

class _DayGroup {
  _DayGroup({required this.day, required this.transactions});
  final DateTime day;
  final List<Transaction> transactions;
}

class _StickyHeader extends ConsumerWidget {
  const _StickyHeader({required this.searchController, required this.period});
  final TextEditingController searchController;
  final Statement? period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Narrowed to just the fields this header renders, so appending a page
    // of transactions during infinite scroll (which changes `.transactions`
    // but not these) doesn't rebuild the search field/filter chips.
    final headerState = ref.watch(activityControllerProvider.select(
      (async) => (
        total: async.valueOrNull?.total,
        typeFilter: async.valueOrNull?.typeFilter,
        category: async.valueOrNull?.category,
        sortByAmount: async.valueOrNull?.sortByAmount,
      ),
    ));
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 12),
      decoration: BoxDecoration(color: AppColors.paper.withValues(alpha: 0.92), border: Border(bottom: BorderSide(color: AppColors.hairlineLight))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity', style: AppTypography.screenTitle24.copyWith(color: AppColors.onLight)),
              Text('${headerState.total ?? period?.transactionCount ?? 0} TXNS', style: AppTypography.microLabel11.copyWith(color: AppColors.onLightFaint)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.field)),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 16, color: AppColors.onLightFaint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: AppTypography.body14.copyWith(fontSize: 13, color: AppColors.onLight),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search merchant, amount, UPI ID',
                      hintStyle: AppTypography.body14.copyWith(fontSize: 13, color: AppColors.onLightFaint),
                    ),
                    onSubmitted: (value) => ref.read(activityControllerProvider.notifier).setMerchantQuery(value.trim()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: 'All', selected: headerState.typeFilter == null, onTap: () => ref.read(activityControllerProvider.notifier).setTypeFilter(null)),
                const SizedBox(width: 7),
                _FilterChip(label: 'Out', selected: headerState.typeFilter == TransactionType.debit, onTap: () => ref.read(activityControllerProvider.notifier).setTypeFilter(TransactionType.debit)),
                const SizedBox(width: 7),
                _FilterChip(label: 'In', selected: headerState.typeFilter == TransactionType.credit, onTap: () => ref.read(activityControllerProvider.notifier).setTypeFilter(TransactionType.credit)),
                const SizedBox(width: 7),
                _FilterChip(
                  label: headerState.category ?? 'Category ▾',
                  selected: headerState.category != null,
                  onTap: () => _pickCategory(context, ref),
                ),
                const SizedBox(width: 7),
                _FilterChip(
                  label: '₹ ▾',
                  selected: headerState.sortByAmount ?? false,
                  onTap: () => ref.read(activityControllerProvider.notifier).toggleAmountSort(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, WidgetRef ref) async {
    final analytics = ref.read(currentPeriodAnalyticsProvider).valueOrNull;
    final categories = analytics?.categoryBreakdown.map((e) => e.category).toList() ?? [];
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: const Text('All categories'), onTap: () => Navigator.of(context).pop()),
            for (final category in categories) ListTile(title: Text(category), onTap: () => Navigator.of(context).pop(category)),
          ],
        ),
      ),
    );
    ref.read(activityControllerProvider.notifier).setCategory(selected);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.onLight : AppColors.card,
            border: Border.all(color: selected ? AppColors.onLight : AppColors.hairlineLight),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label, style: AppTypography.buttonLabel13.copyWith(color: selected ? AppColors.paper : AppColors.onLightMuted)),
        ),
      ),
    );
  }
}
