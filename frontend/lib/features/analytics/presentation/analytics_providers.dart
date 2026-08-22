import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../domain/analytics_models.dart';

final categoryPatternsProvider = FutureProvider.autoDispose<List<CategoryPatternEntry>>((ref) {
  return ref.watch(analyticsRepositoryProvider).categoryPatterns();
});

final merchantPatternsProvider = FutureProvider.autoDispose<List<MerchantPatternEntry>>((ref) {
  return ref.watch(analyticsRepositoryProvider).merchantPatterns(limit: 8);
});

final subscriptionsSummaryProvider = FutureProvider.autoDispose<SubscriptionsSummary>((ref) {
  return ref.watch(analyticsRepositoryProvider).subscriptions();
});

final momTrendProvider = FutureProvider.autoDispose<MoMTrend>((ref) {
  return ref.watch(analyticsRepositoryProvider).trendsMoM();
});
