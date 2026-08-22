class TransactionException {
  final String id;
  final String sourceAMerchant;
  final double sourceAAmount;
  final DateTime sourceADate;
  final String sourceBMerchant;
  final double sourceBAmount;
  final DateTime sourceBDate;
  final String issue;
  final double confidence;
  final String reason;

  TransactionException({
    required this.id,
    required this.sourceAMerchant,
    required this.sourceAAmount,
    required this.sourceADate,
    required this.sourceBMerchant,
    required this.sourceBAmount,
    required this.sourceBDate,
    required this.issue,
    required this.confidence,
    required this.reason,
  });

  factory TransactionException.fromJson(Map<String, dynamic> json) {
    return TransactionException(
      id: json['id'] as String? ?? '',
      sourceAMerchant: json['source_a_merchant'] as String? ?? '',
      sourceAAmount: (json['source_a_amount'] as num?)?.toDouble() ?? 0.0,
      sourceADate: json['source_a_date'] != null
        ? DateTime.parse(json['source_a_date'] as String)
        : DateTime.now(),
      sourceBMerchant: json['source_b_merchant'] as String? ?? '',
      sourceBAmount: (json['source_b_amount'] as num?)?.toDouble() ?? 0.0,
      sourceBDate: json['source_b_date'] != null
        ? DateTime.parse(json['source_b_date'] as String)
        : DateTime.now(),
      issue: json['issue'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_a_merchant': sourceAMerchant,
    'source_a_amount': sourceAAmount,
    'source_a_date': sourceADate.toIso8601String(),
    'source_b_merchant': sourceBMerchant,
    'source_b_amount': sourceBAmount,
    'source_b_date': sourceBDate.toIso8601String(),
    'issue': issue,
    'confidence': confidence,
    'reason': reason,
  };
}
