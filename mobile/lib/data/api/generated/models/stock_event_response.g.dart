// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_event_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockEventResponse _$StockEventResponseFromJson(Map<String, dynamic> json) =>
    StockEventResponse(
      id: json['id'] as String,
      kind: StockEventKind.fromJson(json['kind']),
      quantity: (json['quantity'] as num).toDouble(),
      at: const RequiredDateOnlyConverter().fromJson(json['at'] as String),
      byName: json['byName'] as String?,
      byMe: json['byMe'] as bool,
    );

Map<String, dynamic> _$StockEventResponseToJson(StockEventResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$StockEventKindEnumMap[instance.kind]!,
      'quantity': instance.quantity,
      'at': const RequiredDateOnlyConverter().toJson(instance.at),
      'byName': instance.byName,
      'byMe': instance.byMe,
    };

const _$StockEventKindEnumMap = {
  StockEventKind.purchase: 'Purchase',
  StockEventKind.adjustment: 'Adjustment',
  StockEventKind.$unknown: r'$unknown',
};
