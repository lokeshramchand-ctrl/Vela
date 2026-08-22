// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  String get id => throw _privateConstructorUsedError;
  String? get statementId => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get merchant => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  TransactionType get transactionType => throw _privateConstructorUsedError;
  TransactionStatus get status => throw _privateConstructorUsedError;
  String? get counterpartyRaw => throw _privateConstructorUsedError;
  String? get referenceNumber => throw _privateConstructorUsedError;
  String? get bank => throw _privateConstructorUsedError;
  String? get accountLast4 => throw _privateConstructorUsedError;
  String get paymentMethod => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
    Transaction value,
    $Res Function(Transaction) then,
  ) = _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call({
    String id,
    String? statementId,
    DateTime timestamp,
    String? merchant,
    String? category,
    double amount,
    TransactionType transactionType,
    TransactionStatus status,
    String? counterpartyRaw,
    String? referenceNumber,
    String? bank,
    String? accountLast4,
    String paymentMethod,
  });
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? statementId = freezed,
    Object? timestamp = null,
    Object? merchant = freezed,
    Object? category = freezed,
    Object? amount = null,
    Object? transactionType = null,
    Object? status = null,
    Object? counterpartyRaw = freezed,
    Object? referenceNumber = freezed,
    Object? bank = freezed,
    Object? accountLast4 = freezed,
    Object? paymentMethod = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            statementId: freezed == statementId
                ? _value.statementId
                : statementId // ignore: cast_nullable_to_non_nullable
                      as String?,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            merchant: freezed == merchant
                ? _value.merchant
                : merchant // ignore: cast_nullable_to_non_nullable
                      as String?,
            category: freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String?,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double,
            transactionType: null == transactionType
                ? _value.transactionType
                : transactionType // ignore: cast_nullable_to_non_nullable
                      as TransactionType,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TransactionStatus,
            counterpartyRaw: freezed == counterpartyRaw
                ? _value.counterpartyRaw
                : counterpartyRaw // ignore: cast_nullable_to_non_nullable
                      as String?,
            referenceNumber: freezed == referenceNumber
                ? _value.referenceNumber
                : referenceNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            bank: freezed == bank
                ? _value.bank
                : bank // ignore: cast_nullable_to_non_nullable
                      as String?,
            accountLast4: freezed == accountLast4
                ? _value.accountLast4
                : accountLast4 // ignore: cast_nullable_to_non_nullable
                      as String?,
            paymentMethod: null == paymentMethod
                ? _value.paymentMethod
                : paymentMethod // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
    _$TransactionImpl value,
    $Res Function(_$TransactionImpl) then,
  ) = __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? statementId,
    DateTime timestamp,
    String? merchant,
    String? category,
    double amount,
    TransactionType transactionType,
    TransactionStatus status,
    String? counterpartyRaw,
    String? referenceNumber,
    String? bank,
    String? accountLast4,
    String paymentMethod,
  });
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
    _$TransactionImpl _value,
    $Res Function(_$TransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? statementId = freezed,
    Object? timestamp = null,
    Object? merchant = freezed,
    Object? category = freezed,
    Object? amount = null,
    Object? transactionType = null,
    Object? status = null,
    Object? counterpartyRaw = freezed,
    Object? referenceNumber = freezed,
    Object? bank = freezed,
    Object? accountLast4 = freezed,
    Object? paymentMethod = null,
  }) {
    return _then(
      _$TransactionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        statementId: freezed == statementId
            ? _value.statementId
            : statementId // ignore: cast_nullable_to_non_nullable
                  as String?,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        merchant: freezed == merchant
            ? _value.merchant
            : merchant // ignore: cast_nullable_to_non_nullable
                  as String?,
        category: freezed == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String?,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double,
        transactionType: null == transactionType
            ? _value.transactionType
            : transactionType // ignore: cast_nullable_to_non_nullable
                  as TransactionType,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TransactionStatus,
        counterpartyRaw: freezed == counterpartyRaw
            ? _value.counterpartyRaw
            : counterpartyRaw // ignore: cast_nullable_to_non_nullable
                  as String?,
        referenceNumber: freezed == referenceNumber
            ? _value.referenceNumber
            : referenceNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        bank: freezed == bank
            ? _value.bank
            : bank // ignore: cast_nullable_to_non_nullable
                  as String?,
        accountLast4: freezed == accountLast4
            ? _value.accountLast4
            : accountLast4 // ignore: cast_nullable_to_non_nullable
                  as String?,
        paymentMethod: null == paymentMethod
            ? _value.paymentMethod
            : paymentMethod // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl implements _Transaction {
  const _$TransactionImpl({
    required this.id,
    this.statementId,
    required this.timestamp,
    this.merchant,
    this.category,
    required this.amount,
    required this.transactionType,
    required this.status,
    this.counterpartyRaw,
    this.referenceNumber,
    this.bank,
    this.accountLast4,
    required this.paymentMethod,
  });

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final String id;
  @override
  final String? statementId;
  @override
  final DateTime timestamp;
  @override
  final String? merchant;
  @override
  final String? category;
  @override
  final double amount;
  @override
  final TransactionType transactionType;
  @override
  final TransactionStatus status;
  @override
  final String? counterpartyRaw;
  @override
  final String? referenceNumber;
  @override
  final String? bank;
  @override
  final String? accountLast4;
  @override
  final String paymentMethod;

  @override
  String toString() {
    return 'Transaction(id: $id, statementId: $statementId, timestamp: $timestamp, merchant: $merchant, category: $category, amount: $amount, transactionType: $transactionType, status: $status, counterpartyRaw: $counterpartyRaw, referenceNumber: $referenceNumber, bank: $bank, accountLast4: $accountLast4, paymentMethod: $paymentMethod)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.statementId, statementId) ||
                other.statementId == statementId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.merchant, merchant) ||
                other.merchant == merchant) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.counterpartyRaw, counterpartyRaw) ||
                other.counterpartyRaw == counterpartyRaw) &&
            (identical(other.referenceNumber, referenceNumber) ||
                other.referenceNumber == referenceNumber) &&
            (identical(other.bank, bank) || other.bank == bank) &&
            (identical(other.accountLast4, accountLast4) ||
                other.accountLast4 == accountLast4) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    statementId,
    timestamp,
    merchant,
    category,
    amount,
    transactionType,
    status,
    counterpartyRaw,
    referenceNumber,
    bank,
    accountLast4,
    paymentMethod,
  );

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(this);
  }
}

abstract class _Transaction implements Transaction {
  const factory _Transaction({
    required final String id,
    final String? statementId,
    required final DateTime timestamp,
    final String? merchant,
    final String? category,
    required final double amount,
    required final TransactionType transactionType,
    required final TransactionStatus status,
    final String? counterpartyRaw,
    final String? referenceNumber,
    final String? bank,
    final String? accountLast4,
    required final String paymentMethod,
  }) = _$TransactionImpl;

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  String get id;
  @override
  String? get statementId;
  @override
  DateTime get timestamp;
  @override
  String? get merchant;
  @override
  String? get category;
  @override
  double get amount;
  @override
  TransactionType get transactionType;
  @override
  TransactionStatus get status;
  @override
  String? get counterpartyRaw;
  @override
  String? get referenceNumber;
  @override
  String? get bank;
  @override
  String? get accountLast4;
  @override
  String get paymentMethod;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TransactionListResponse _$TransactionListResponseFromJson(
  Map<String, dynamic> json,
) {
  return _TransactionListResponse.fromJson(json);
}

/// @nodoc
mixin _$TransactionListResponse {
  List<Transaction> get items => throw _privateConstructorUsedError;
  int get page => throw _privateConstructorUsedError;
  int get pageSize => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get totalPages => throw _privateConstructorUsedError;

  /// Serializes this TransactionListResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TransactionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionListResponseCopyWith<TransactionListResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionListResponseCopyWith<$Res> {
  factory $TransactionListResponseCopyWith(
    TransactionListResponse value,
    $Res Function(TransactionListResponse) then,
  ) = _$TransactionListResponseCopyWithImpl<$Res, TransactionListResponse>;
  @useResult
  $Res call({
    List<Transaction> items,
    int page,
    int pageSize,
    int total,
    int totalPages,
  });
}

/// @nodoc
class _$TransactionListResponseCopyWithImpl<
  $Res,
  $Val extends TransactionListResponse
>
    implements $TransactionListResponseCopyWith<$Res> {
  _$TransactionListResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TransactionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? page = null,
    Object? pageSize = null,
    Object? total = null,
    Object? totalPages = null,
  }) {
    return _then(
      _value.copyWith(
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<Transaction>,
            page: null == page
                ? _value.page
                : page // ignore: cast_nullable_to_non_nullable
                      as int,
            pageSize: null == pageSize
                ? _value.pageSize
                : pageSize // ignore: cast_nullable_to_non_nullable
                      as int,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPages: null == totalPages
                ? _value.totalPages
                : totalPages // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionListResponseImplCopyWith<$Res>
    implements $TransactionListResponseCopyWith<$Res> {
  factory _$$TransactionListResponseImplCopyWith(
    _$TransactionListResponseImpl value,
    $Res Function(_$TransactionListResponseImpl) then,
  ) = __$$TransactionListResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Transaction> items,
    int page,
    int pageSize,
    int total,
    int totalPages,
  });
}

/// @nodoc
class __$$TransactionListResponseImplCopyWithImpl<$Res>
    extends
        _$TransactionListResponseCopyWithImpl<
          $Res,
          _$TransactionListResponseImpl
        >
    implements _$$TransactionListResponseImplCopyWith<$Res> {
  __$$TransactionListResponseImplCopyWithImpl(
    _$TransactionListResponseImpl _value,
    $Res Function(_$TransactionListResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TransactionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? page = null,
    Object? pageSize = null,
    Object? total = null,
    Object? totalPages = null,
  }) {
    return _then(
      _$TransactionListResponseImpl(
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<Transaction>,
        page: null == page
            ? _value.page
            : page // ignore: cast_nullable_to_non_nullable
                  as int,
        pageSize: null == pageSize
            ? _value.pageSize
            : pageSize // ignore: cast_nullable_to_non_nullable
                  as int,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPages: null == totalPages
            ? _value.totalPages
            : totalPages // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionListResponseImpl implements _TransactionListResponse {
  const _$TransactionListResponseImpl({
    required final List<Transaction> items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  }) : _items = items;

  factory _$TransactionListResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionListResponseImplFromJson(json);

  final List<Transaction> _items;
  @override
  List<Transaction> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int page;
  @override
  final int pageSize;
  @override
  final int total;
  @override
  final int totalPages;

  @override
  String toString() {
    return 'TransactionListResponse(items: $items, page: $page, pageSize: $pageSize, total: $total, totalPages: $totalPages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionListResponseImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.pageSize, pageSize) ||
                other.pageSize == pageSize) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.totalPages, totalPages) ||
                other.totalPages == totalPages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_items),
    page,
    pageSize,
    total,
    totalPages,
  );

  /// Create a copy of TransactionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionListResponseImplCopyWith<_$TransactionListResponseImpl>
  get copyWith =>
      __$$TransactionListResponseImplCopyWithImpl<
        _$TransactionListResponseImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionListResponseImplToJson(this);
  }
}

abstract class _TransactionListResponse implements TransactionListResponse {
  const factory _TransactionListResponse({
    required final List<Transaction> items,
    required final int page,
    required final int pageSize,
    required final int total,
    required final int totalPages,
  }) = _$TransactionListResponseImpl;

  factory _TransactionListResponse.fromJson(Map<String, dynamic> json) =
      _$TransactionListResponseImpl.fromJson;

  @override
  List<Transaction> get items;
  @override
  int get page;
  @override
  int get pageSize;
  @override
  int get total;
  @override
  int get totalPages;

  /// Create a copy of TransactionListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionListResponseImplCopyWith<_$TransactionListResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}
