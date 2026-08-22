import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../../statements/domain/transaction.dart';
import '../../statements/presentation/period_providers.dart';

class ActivityState {
  const ActivityState({
    this.transactions = const [],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoadingMore = false,
    this.errorMessage,
    this.typeFilter,
    this.category,
    this.sortByAmount = false,
    this.merchantQuery = '',
  });

  final List<Transaction> transactions;
  final int page;
  final int totalPages;
  final int total;
  final bool isLoadingMore;
  final String? errorMessage;
  final TransactionType? typeFilter;
  final String? category;
  final bool sortByAmount;
  final String merchantQuery;

  bool get hasMore => page < totalPages;

  ActivityState copyWith({
    List<Transaction>? transactions,
    int? page,
    int? totalPages,
    int? total,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    TransactionType? typeFilter,
    bool clearTypeFilter = false,
    String? category,
    bool clearCategory = false,
    bool? sortByAmount,
    String? merchantQuery,
  }) {
    return ActivityState(
      transactions: transactions ?? this.transactions,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      category: clearCategory ? null : (category ?? this.category),
      sortByAmount: sortByAmount ?? this.sortByAmount,
      merchantQuery: merchantQuery ?? this.merchantQuery,
    );
  }
}

final activityControllerProvider = AsyncNotifierProvider<ActivityController, ActivityState>(ActivityController.new);

class ActivityController extends AsyncNotifier<ActivityState> {
  @override
  Future<ActivityState> build() async {
    final period = ref.watch(currentPeriodProvider);
    if (period == null) return const ActivityState();
    return _fetch(statementId: period.id, state: const ActivityState());
  }

  Future<ActivityState> _fetch({required String statementId, required ActivityState state, int page = 1, bool append = false}) async {
    final repo = ref.read(statementsRepositoryProvider);
    final result = await repo.transactions(
      statementId,
      page: page,
      pageSize: 30,
      category: state.category,
      transactionType: state.typeFilter,
      merchant: state.merchantQuery.isEmpty ? null : state.merchantQuery,
      sortBy: state.sortByAmount ? 'amount' : 'timestamp',
      sortOrder: 'desc',
    );
    return state.copyWith(
      transactions: append ? [...state.transactions, ...result.items] : result.items,
      page: result.page,
      totalPages: result.totalPages,
      total: result.total,
      isLoadingMore: false,
      clearError: true,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final period = ref.read(currentPeriodProvider);
    if (current == null || period == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(statementId: period.id, state: current, page: current.page + 1, append: true);
      state = AsyncData(next);
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false, errorMessage: 'Could not load more transactions.'));
    }
  }

  Future<void> _applyFilters(ActivityState Function(ActivityState) transform) async {
    final period = ref.read(currentPeriodProvider);
    if (period == null) return;
    final base = transform(state.valueOrNull ?? const ActivityState());
    state = const AsyncLoading<ActivityState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetch(statementId: period.id, state: base));
  }

  Future<void> setTypeFilter(TransactionType? type) => _applyFilters((s) => s.copyWith(typeFilter: type, clearTypeFilter: type == null));
  Future<void> setCategory(String? category) => _applyFilters((s) => s.copyWith(category: category, clearCategory: category == null));
  Future<void> toggleAmountSort() => _applyFilters((s) => s.copyWith(sortByAmount: !s.sortByAmount));
  Future<void> setMerchantQuery(String query) => _applyFilters((s) => s.copyWith(merchantQuery: query));
}
