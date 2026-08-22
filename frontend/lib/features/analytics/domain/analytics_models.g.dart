// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryPatternEntryImpl _$$CategoryPatternEntryImplFromJson(
  Map<String, dynamic> json,
) => _$CategoryPatternEntryImpl(
  category: json['category'] as String? ?? 'Unknown',
  totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
  count: (json['count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$CategoryPatternEntryImplToJson(
  _$CategoryPatternEntryImpl instance,
) => <String, dynamic>{
  'category': instance.category,
  'total_amount': instance.totalAmount,
  'count': instance.count,
};

_$MerchantPatternEntryImpl _$$MerchantPatternEntryImplFromJson(
  Map<String, dynamic> json,
) => _$MerchantPatternEntryImpl(
  merchant: json['merchant'] as String?,
  visits: (json['visits'] as num?)?.toInt() ?? 0,
  spent: (json['spent'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$$MerchantPatternEntryImplToJson(
  _$MerchantPatternEntryImpl instance,
) => <String, dynamic>{
  'merchant': instance.merchant,
  'visits': instance.visits,
  'spent': instance.spent,
};

_$SubscriptionDetailImpl _$$SubscriptionDetailImplFromJson(
  Map<String, dynamic> json,
) => _$SubscriptionDetailImpl(
  merchant: json['merchant'] as String,
  estimatedMonthlyCost: (json['estimated_monthly_cost'] as num).toDouble(),
  periodicityScore: (json['periodicity_score'] as num).toDouble(),
  lastBilled: json['last_billed'] == null
      ? null
      : DateTime.parse(json['last_billed'] as String),
);

Map<String, dynamic> _$$SubscriptionDetailImplToJson(
  _$SubscriptionDetailImpl instance,
) => <String, dynamic>{
  'merchant': instance.merchant,
  'estimated_monthly_cost': instance.estimatedMonthlyCost,
  'periodicity_score': instance.periodicityScore,
  'last_billed': instance.lastBilled?.toIso8601String(),
};

_$SubscriptionsSummaryImpl _$$SubscriptionsSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$SubscriptionsSummaryImpl(
  activeSubscriptions: (json['active_subscriptions'] as num?)?.toInt() ?? 0,
  totalMonthlyBurn: (json['total_monthly_burn'] as num?)?.toDouble() ?? 0,
  details:
      (json['details'] as List<dynamic>?)
          ?.map((e) => SubscriptionDetail.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SubscriptionDetail>[],
);

Map<String, dynamic> _$$SubscriptionsSummaryImplToJson(
  _$SubscriptionsSummaryImpl instance,
) => <String, dynamic>{
  'active_subscriptions': instance.activeSubscriptions,
  'total_monthly_burn': instance.totalMonthlyBurn,
  'details': instance.details.map((e) => e.toJson()).toList(),
};

_$MoMTrendImpl _$$MoMTrendImplFromJson(Map<String, dynamic> json) =>
    _$MoMTrendImpl(
      currentSpend: (json['current_spend'] as num?)?.toDouble() ?? 0,
      previousSpend: (json['previous_spend'] as num?)?.toDouble() ?? 0,
      momGrowthPercentage:
          (json['mom_growth_percentage'] as num?)?.toDouble() ?? 0,
      trend: json['trend'] as String? ?? 'down',
    );

Map<String, dynamic> _$$MoMTrendImplToJson(_$MoMTrendImpl instance) =>
    <String, dynamic>{
      'current_spend': instance.currentSpend,
      'previous_spend': instance.previousSpend,
      'mom_growth_percentage': instance.momGrowthPercentage,
      'trend': instance.trend,
    };

_$AnomalyCheckResultImpl _$$AnomalyCheckResultImplFromJson(
  Map<String, dynamic> json,
) => _$AnomalyCheckResultImpl(
  isAnomaly: json['is_anomaly'] as bool,
  reason: json['reason'] as String,
  confidence: (json['confidence'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$AnomalyCheckResultImplToJson(
  _$AnomalyCheckResultImpl instance,
) => <String, dynamic>{
  'is_anomaly': instance.isAnomaly,
  'reason': instance.reason,
  'confidence': instance.confidence,
};
