import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType {
  @JsonValue('DEBIT')
  debit,
  @JsonValue('CREDIT')
  credit,
}

enum TransactionStatus {
  @JsonValue('SUCCESS')
  success,
  @JsonValue('FAILED')
  failed,
  @JsonValue('PENDING')
  pending,
}

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    String? statementId,
    required DateTime timestamp,
    String? merchant,
    String? category,
    required double amount,
    required TransactionType transactionType,
    required TransactionStatus status,
    String? counterpartyRaw,
    String? referenceNumber,
    String? bank,
    String? accountLast4,
    required String paymentMethod,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);
}

@freezed
abstract class TransactionListResponse with _$TransactionListResponse {
  const factory TransactionListResponse({
    required List<Transaction> items,
    required int page,
    required int pageSize,
    required int total,
    required int totalPages,
  }) = _TransactionListResponse;

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) => _$TransactionListResponseFromJson(json);
}
