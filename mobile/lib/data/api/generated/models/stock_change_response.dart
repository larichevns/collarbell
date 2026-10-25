// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'stock_event_response.dart';
import 'supply_response.dart';

part 'stock_change_response.g.dart';

@JsonSerializable()
class StockChangeResponse {
  const StockChangeResponse({
    required this.event,
    required this.supply,
  });
  
  factory StockChangeResponse.fromJson(Map<String, Object?> json) => _$StockChangeResponseFromJson(json);
  
  final StockEventResponse event;
  final SupplyResponse supply;

  Map<String, Object?> toJson() => _$StockChangeResponseToJson(this);
}
