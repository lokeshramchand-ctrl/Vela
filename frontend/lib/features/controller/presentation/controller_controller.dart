import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/reconciliation_stats.dart';
import '../domain/exception.dart';
import '../domain/cash_position.dart';
import 'mock_controller_data.dart';

class ControllerState {
  final ReconciliationStats stats;
  final List<TransactionException> exceptions;
  final CashPosition? cashPosition;
  final bool isLoading;
  final String? error;

  ControllerState({
    required this.stats,
    required this.exceptions,
    this.cashPosition,
    required this.isLoading,
    this.error,
  });

  ControllerState copyWith({
    ReconciliationStats? stats,
    List<TransactionException>? exceptions,
    CashPosition? cashPosition,
    bool? isLoading,
    String? error,
  }) {
    return ControllerState(
      stats: stats ?? this.stats,
      exceptions: exceptions ?? this.exceptions,
      cashPosition: cashPosition ?? this.cashPosition,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ControllerNotifier extends StateNotifier<ControllerState> {
  final ApiClient _apiClient;

  ControllerNotifier(this._apiClient)
    : super(
      ControllerState(
        stats: ReconciliationStats(
          recordsProcessed: 0,
          matched: 0,
          exceptions: 0,
          unresolved: 0,
          matchRate: 0.0,
          amountReconciled: 0.0,
        ),
        exceptions: [],
        isLoading: true,
      ),
    ) {
    _initialize();
  }

  Future<void> _initialize() async {
    await fetchStats();
    await fetchExceptions();
    await fetchCashPosition();
  }

  Future<void> fetchStats() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final stats = kDebugMode
        ? await MockControllerRepository.fetchStats()
        : ReconciliationStats.fromJson(
          (await _apiClient.get('/api/controller/stats')).data
        );
      state = state.copyWith(stats: stats, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchExceptions() async {
    try {
      final exceptions = kDebugMode
        ? await MockControllerRepository.fetchExceptions()
        : ((await _apiClient.get('/api/controller/exceptions')).data['exceptions'] as List?)
          ?.map((e) => TransactionException.fromJson(e as Map<String, dynamic>))
          .toList() ?? [];
      state = state.copyWith(exceptions: exceptions);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> fetchCashPosition() async {
    try {
      final cashPosition = kDebugMode
        ? await MockControllerRepository.fetchCashPosition()
        : CashPosition.fromJson(
          (await _apiClient.get('/api/controller/cash-position')).data
        );
      state = state.copyWith(cashPosition: cashPosition);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> resolveException(String exceptionId, bool approved) async {
    try {
      if (kDebugMode) {
        await MockControllerRepository.resolveException(exceptionId, approved);
      } else {
        await _apiClient.post(
          '/api/controller/exceptions/$exceptionId/resolve',
          data: {'approved': approved},
        );
      }
      state = state.copyWith(
        exceptions: state.exceptions
          .where((e) => e.id != exceptionId)
          .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() async {
    await fetchStats();
    await fetchExceptions();
    await fetchCashPosition();
  }
}

final controllerProvider = StateNotifierProvider<ControllerNotifier, ControllerState>(
  (ref) => ControllerNotifier(ref.watch(apiClientProvider)),
);
