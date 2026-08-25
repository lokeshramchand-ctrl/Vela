import 'package:flutter/foundation.dart';
import '../domain/reconciliation_stats.dart';
import '../domain/exception.dart';
import '../domain/cash_position.dart';
import 'dart:async';

class MockControllerRepository {
  static Future<ReconciliationStats> fetchStats() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return ReconciliationStats(
      recordsProcessed: 250,
      matched: 221,
      exceptions: 21,
      unresolved: 8,
      matchRate: 0.884,
      amountReconciled: 482300.0,
    );
  }

  static Future<List<TransactionException>> fetchExceptions() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return [
      TransactionException(
        id: '1',
        sourceAMerchant: 'Amazon',
        sourceAAmount: 2499.0,
        sourceADate: DateTime(2026, 8, 10),
        sourceBMerchant: 'Amazon Pay',
        sourceBAmount: 2599.0,
        sourceBDate: DateTime(2026, 8, 10),
        issue: 'Amount mismatch',
        confidence: 0.98,
        reason: 'Merchant and date align, but amounts differ by ₹100.',
      ),
      TransactionException(
        id: '2',
        sourceAMerchant: 'Swiggy',
        sourceAAmount: 450.0,
        sourceADate: DateTime(2026, 8, 15),
        sourceBMerchant: 'Swiggy Eats',
        sourceBAmount: 460.0,
        sourceBDate: DateTime(2026, 8, 14),
        issue: 'Partial date mismatch',
        confidence: 0.72,
        reason: 'Merchant names differ slightly and transactions are on different days.',
      ),
      TransactionException(
        id: '3',
        sourceAMerchant: 'Uber India',
        sourceAAmount: 382.0,
        sourceADate: DateTime(2026, 8, 12),
        sourceBMerchant: 'Uber Eats',
        sourceBAmount: 385.0,
        sourceBDate: DateTime(2026, 8, 12),
        issue: 'Merchant name variant',
        confidence: 0.65,
        reason: 'Could be Uber Eats vs regular Uber. Amount variance is within 1%.',
      ),
    ];
  }

  static Future<CashPosition> fetchCashPosition() async {
    await Future.delayed(const Duration(milliseconds: 900));
    const openingBalance = 50000.0;
    const verifiedInflows = 62300.0;
    const verifiedOutflows = 29800.0;
    const expectedClosingBalance = openingBalance + verifiedInflows - verifiedOutflows;
    const reportedClosingBalance = 80000.0;
    return CashPosition(
      openingBalance: openingBalance,
      verifiedInflows: verifiedInflows,
      verifiedOutflows: verifiedOutflows,
      expectedClosingBalance: expectedClosingBalance,
      reportedClosingBalance: reportedClosingBalance,
      variance: reportedClosingBalance - expectedClosingBalance,
      contributingExceptions: await fetchExceptions(),
    );
  }

  static Future<void> resolveException(String exceptionId, bool approved) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (kDebugMode) {
      print('Resolved exception $exceptionId with approved=$approved');
    }
  }
}
