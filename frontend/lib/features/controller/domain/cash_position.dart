import 'exception.dart';

class CashPosition {
  final double openingBalance;
  final double verifiedInflows;
  final double verifiedOutflows;
  final double expectedClosingBalance;
  final double reportedClosingBalance;
  final double variance;
  final List<TransactionException> contributingExceptions;

  CashPosition({
    required this.openingBalance,
    required this.verifiedInflows,
    required this.verifiedOutflows,
    required this.expectedClosingBalance,
    required this.reportedClosingBalance,
    required this.variance,
    required this.contributingExceptions,
  });

  bool get isBalanced => variance.abs() < 0.01;

  factory CashPosition.fromJson(Map<String, dynamic> json) {
    return CashPosition(
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      verifiedInflows: (json['verified_inflows'] as num?)?.toDouble() ?? 0.0,
      verifiedOutflows: (json['verified_outflows'] as num?)?.toDouble() ?? 0.0,
      expectedClosingBalance: (json['expected_closing_balance'] as num?)?.toDouble() ?? 0.0,
      reportedClosingBalance: (json['reported_closing_balance'] as num?)?.toDouble() ?? 0.0,
      variance: (json['variance'] as num?)?.toDouble() ?? 0.0,
      contributingExceptions: (json['contributing_exceptions'] as List?)
        ?.map((e) => TransactionException.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'opening_balance': openingBalance,
    'verified_inflows': verifiedInflows,
    'verified_outflows': verifiedOutflows,
    'expected_closing_balance': expectedClosingBalance,
    'reported_closing_balance': reportedClosingBalance,
    'variance': variance,
    'contributing_exceptions': contributingExceptions.map((e) => e.toJson()).toList(),
  };
}
