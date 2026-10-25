// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'stock_event_kind.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'stock_event_response.g.dart';

@JsonSerializable()
class StockEventResponse {
  const StockEventResponse({
    required this.id,
    required this.kind,
    required this.quantity,
    required this.at,
    required this.byName,
    required this.byMe,
  });
  
  factory StockEventResponse.fromJson(Map<String, Object?> json) => _$StockEventResponseFromJson(json);
  
  final String id;
  final StockEventKind kind;
  final double quantity;
	@RequiredDateOnlyConverter()
  final DateTime at;
  final String? byName;
  final bool byMe;

  Map<String, Object?> toJson() => _$StockEventResponseToJson(this);
}
