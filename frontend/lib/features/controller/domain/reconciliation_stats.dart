class ReconciliationStats {
  final int recordsProcessed;
  final int matched;
  final int exceptions;
  final int unresolved;
  final double matchRate;
  final double amountReconciled;

  ReconciliationStats({
    required this.recordsProcessed,
    required this.matched,
    required this.exceptions,
    required this.unresolved,
    required this.matchRate,
    required this.amountReconciled,
  });

  factory ReconciliationStats.fromJson(Map<String, dynamic> json) {
    return ReconciliationStats(
      recordsProcessed: json['records_processed'] as int? ?? 0,
      matched: json['matched'] as int? ?? 0,
      exceptions: json['exceptions'] as int? ?? 0,
      unresolved: json['unresolved'] as int? ?? 0,
      matchRate: (json['match_rate'] as num?)?.toDouble() ?? 0.0,
      amountReconciled: (json['amount_reconciled'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'records_processed': recordsProcessed,
    'matched': matched,
    'exceptions': exceptions,
    'unresolved': unresolved,
    'match_rate': matchRate,
    'amount_reconciled': amountReconciled,
  };
}
