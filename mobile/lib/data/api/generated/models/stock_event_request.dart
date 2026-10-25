// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'stock_event_kind.dart';

part 'stock_event_request.g.dart';

@JsonSerializable()
class StockEventRequest {
  const StockEventRequest({
    required this.kind,
    required this.quantity,
    required this.requestId,
  });
  
  factory StockEventRequest.fromJson(Map<String, Object?> json) => _$StockEventRequestFromJson(json);
  
  final StockEventKind kind;
  final double quantity;
  final String? requestId;

  Map<String, Object?> toJson() => _$StockEventRequestToJson(this);
}
