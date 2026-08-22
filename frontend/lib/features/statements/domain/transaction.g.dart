// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: json['id'] as String,
      statementId: json['statement_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      merchant: json['merchant'] as String?,
      category: json['category'] as String?,
      amount: (json['amount'] as num).toDouble(),
      transactionType: $enumDecode(
        _$TransactionTypeEnumMap,
        json['transaction_type'],
      ),
      status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
      counterpartyRaw: json['counterparty_raw'] as String?,
      referenceNumber: json['reference_number'] as String?,
      bank: json['bank'] as String?,
      accountLast4: json['account_last4'] as String?,
      paymentMethod: json['payment_method'] as String,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'statement_id': instance.statementId,
      'timestamp': instance.timestamp.toIso8601String(),
      'merchant': instance.merchant,
      'category': instance.category,
      'amount': instance.amount,
      'transaction_type': _$TransactionTypeEnumMap[instance.transactionType]!,
      'status': _$TransactionStatusEnumMap[instance.status]!,
      'counterparty_raw': instance.counterpartyRaw,
      'reference_number': instance.referenceNumber,
      'bank': instance.bank,
      'account_last4': instance.accountLast4,
      'payment_method': instance.paymentMethod,
    };

const _$TransactionTypeEnumMap = {
  TransactionType.debit: 'DEBIT',
  TransactionType.credit: 'CREDIT',
};

const _$TransactionStatusEnumMap = {
  TransactionStatus.success: 'SUCCESS',
  TransactionStatus.failed: 'FAILED',
  TransactionStatus.pending: 'PENDING',
};

_$TransactionListResponseImpl _$$TransactionListResponseImplFromJson(
  Map<String, dynamic> json,
) => _$TransactionListResponseImpl(
  items: (json['items'] as List<dynamic>)
      .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
      .toList(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['page_size'] as num).toInt(),
  total: (json['total'] as num).toInt(),
  totalPages: (json['total_pages'] as num).toInt(),
);

Map<String, dynamic> _$$TransactionListResponseImplToJson(
  _$TransactionListResponseImpl instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'page': instance.page,
  'page_size': instance.pageSize,
  'total': instance.total,
  'total_pages': instance.totalPages,
};
