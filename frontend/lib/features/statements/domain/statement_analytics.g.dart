// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statement_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryBreakdownEntryImpl _$$CategoryBreakdownEntryImplFromJson(
  Map<String, dynamic> json,
) => _$CategoryBreakdownEntryImpl(
  category: json['category'] as String,
  totalAmount: (json['total_amount'] as num).toDouble(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$$CategoryBreakdownEntryImplToJson(
  _$CategoryBreakdownEntryImpl instance,
) => <String, dynamic>{
  'category': instance.category,
  'total_amount': instance.totalAmount,
  'count': instance.count,
};

_$TopMerchantEntryImpl _$$TopMerchantEntryImplFromJson(
  Map<String, dynamic> json,
) => _$TopMerchantEntryImpl(
  merchant: json['merchant'] as String,
  totalAmount: (json['total_amount'] as num).toDouble(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$$TopMerchantEntryImplToJson(
  _$TopMerchantEntryImpl instance,
) => <String, dynamic>{
  'merchant': instance.merchant,
  'total_amount': instance.totalAmount,
  'count': instance.count,
};

_$DailyTrendEntryImpl _$$DailyTrendEntryImplFromJson(
  Map<String, dynamic> json,
) => _$DailyTrendEntryImpl(
  date: DateTime.parse(json['date'] as String),
  totalAmount: (json['total_amount'] as num).toDouble(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$$DailyTrendEntryImplToJson(
  _$DailyTrendEntryImpl instance,
) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'total_amount': instance.totalAmount,
  'count': instance.count,
};

_$RecurringPaymentEntryImpl _$$RecurringPaymentEntryImplFromJson(
  Map<String, dynamic> json,
) => _$RecurringPaymentEntryImpl(
  merchant: json['merchant'] as String,
  estimatedMonthlyCost: (json['estimated_monthly_cost'] as num).toDouble(),
  periodicityScore: (json['periodicity_score'] as num).toDouble(),
  occurrences: (json['occurrences'] as num).toInt(),
);

Map<String, dynamic> _$$RecurringPaymentEntryImplToJson(
  _$RecurringPaymentEntryImpl instance,
) => <String, dynamic>{
  'merchant': instance.merchant,
  'estimated_monthly_cost': instance.estimatedMonthlyCost,
  'periodicity_score': instance.periodicityScore,
  'occurrences': instance.occurrences,
};

_$StatementAnalyticsImpl _$$StatementAnalyticsImplFromJson(
  Map<String, dynamic> json,
) => _$StatementAnalyticsImpl(
  statementId: json['statement_id'] as String,
  totalSpend: (json['total_spend'] as num).toDouble(),
  totalIncome: (json['total_income'] as num).toDouble(),
  net: (json['net'] as num).toDouble(),
  averageTransactionValue: (json['average_transaction_value'] as num)
      .toDouble(),
  transactionCount: (json['transaction_count'] as num).toInt(),
  failedTransactionCount: (json['failed_transaction_count'] as num).toInt(),
  categoryBreakdown: (json['category_breakdown'] as List<dynamic>)
      .map((e) => CategoryBreakdownEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  topMerchants: (json['top_merchants'] as List<dynamic>)
      .map((e) => TopMerchantEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  dailyTrend: (json['daily_trend'] as List<dynamic>)
      .map((e) => DailyTrendEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  recurringPayments: (json['recurring_payments'] as List<dynamic>)
      .map((e) => RecurringPaymentEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  generatedAt: DateTime.parse(json['generated_at'] as String),
);

Map<String, dynamic> _$$StatementAnalyticsImplToJson(
  _$StatementAnalyticsImpl instance,
) => <String, dynamic>{
  'statement_id': instance.statementId,
  'total_spend': instance.totalSpend,
  'total_income': instance.totalIncome,
  'net': instance.net,
  'average_transaction_value': instance.averageTransactionValue,
  'transaction_count': instance.transactionCount,
  'failed_transaction_count': instance.failedTransactionCount,
  'category_breakdown': instance.categoryBreakdown
      .map((e) => e.toJson())
      .toList(),
  'top_merchants': instance.topMerchants.map((e) => e.toJson()).toList(),
  'daily_trend': instance.dailyTrend.map((e) => e.toJson()).toList(),
  'recurring_payments': instance.recurringPayments
      .map((e) => e.toJson())
      .toList(),
  'generated_at': instance.generatedAt.toIso8601String(),
};
