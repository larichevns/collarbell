// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_change_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockChangeResponse _$StockChangeResponseFromJson(Map<String, dynamic> json) =>
    StockChangeResponse(
      event: StockEventResponse.fromJson(json['event'] as Map<String, dynamic>),
      supply: SupplyResponse.fromJson(json['supply'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StockChangeResponseToJson(
  StockChangeResponse instance,
) => <String, dynamic>{
  'event': instance.event.toJson(),
  'supply': instance.supply.toJson(),
};
