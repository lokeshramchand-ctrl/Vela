import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../../statements/domain/transaction.dart';
import '../../statements/presentation/period_providers.dart';

class MerchantAggregate {
  const MerchantAggregate({required this.merchant, required this.count, required this.total});
  final String merchant;
  final int count;
  final double total;
  double get average => count == 0 ? 0 : total / count;
}

class MonthlyBucket {
  const MonthlyBucket({required this.year, required this.month, required this.total});
  final int year;
  final int month;
  final double total;
}

class CategoryDrilldown {
  const CategoryDrilldown({required this.merchants, required this.monthlyBuckets});
  final List<MerchantAggregate> merchants;
  final List<MonthlyBucket> monthlyBuckets;
}

/// Aggregates a category's merchants and monthly spend client-side from
/// `/statements/{id}/transactions?category=...` - there's no per-category
/// merchant/monthly breakdown endpoint, so this derives it from the same
/// real transaction records Activity uses. Capped at 3 pages (300 txns) as
/// a sane bound for a single category within one statement.
///
/// `autoDispose` because this is keyed per-category: without it, every
/// category the user ever drills into (each holding up to 300 fetched
/// transactions) would stay cached for the app's lifetime instead of being
/// released once the drilldown screen closes.
final categoryDrilldownProvider = FutureProvider.autoDispose.family<CategoryDrilldown, String>((ref, category) async {
  final period = ref.watch(currentPeriodProvider);
  if (period == null) return const CategoryDrilldown(merchants: [], monthlyBuckets: []);

  final repo = ref.watch(statementsRepositoryProvider);
  final transactions = <Transaction>[];
  var page = 1;
  const maxPages = 3;
  while (page <= maxPages) {
    final result = await repo.transactions(
      period.id,
      page: page,
      pageSize: 100,
      category: category,
      transactionType: TransactionType.debit,
      sortBy: 'timestamp',
      sortOrder: 'desc',
    );
    transactions.addAll(result.items);
    if (page >= result.totalPages) break;
    page++;
  }

  final merchantTotals = <String, MerchantAggregate>{};
  final monthlyTotals = <String, double>{};
  for (final txn in transactions) {
    final merchantName = txn.merchant ?? 'Unknown merchant';
    final existing = merchantTotals[merchantName];
    merchantTotals[merchantName] = MerchantAggregate(
      merchant: merchantName,
      count: (existing?.count ?? 0) + 1,
      total: (existing?.total ?? 0) + txn.amount,
    );
    final key = '${txn.timestamp.year}-${txn.timestamp.month}';
    monthlyTotals[key] = (monthlyTotals[key] ?? 0) + txn.amount;
  }

  final merchants = merchantTotals.values.toList()..sort((a, b) => b.total.compareTo(a.total));

  final buckets = <MonthlyBucket>[];
  var cursor = DateTime(period.periodStart.year, period.periodStart.month);
  final end = DateTime(period.periodEnd.year, period.periodEnd.month);
  while (!cursor.isAfter(end)) {
    buckets.add(MonthlyBucket(year: cursor.year, month: cursor.month, total: monthlyTotals['${cursor.year}-${cursor.month}'] ?? 0));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }

  return CategoryDrilldown(merchants: merchants, monthlyBuckets: buckets);
});
