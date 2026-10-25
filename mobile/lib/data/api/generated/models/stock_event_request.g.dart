// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_event_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockEventRequest _$StockEventRequestFromJson(Map<String, dynamic> json) =>
    StockEventRequest(
      kind: StockEventKind.fromJson(json['kind']),
      quantity: (json['quantity'] as num).toDouble(),
      requestId: json['requestId'] as String?,
    );

Map<String, dynamic> _$StockEventRequestToJson(StockEventRequest instance) =>
    <String, dynamic>{
      'kind': _$StockEventKindEnumMap[instance.kind]!,
      'quantity': instance.quantity,
      'requestId': instance.requestId,
    };

const _$StockEventKindEnumMap = {
  StockEventKind.purchase: 'Purchase',
  StockEventKind.adjustment: 'Adjustment',
  StockEventKind.$unknown: r'$unknown',
};
