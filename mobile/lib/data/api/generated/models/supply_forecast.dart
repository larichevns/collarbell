// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'supply_status.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'supply_forecast.g.dart';

@JsonSerializable()
class SupplyForecast {
  const SupplyForecast({
    required this.remaining,
    required this.usagePerDay,
    required this.daysLeft,
    required this.runsOutOn,
    required this.buyBy,
    required this.status,
    required this.countedFrom,
  });
  
  factory SupplyForecast.fromJson(Map<String, Object?> json) => _$SupplyForecastFromJson(json);
  
  final double? remaining;
  final double? usagePerDay;
  final double? daysLeft;
	@DateOnlyConverter()
  final DateTime? runsOutOn;
	@DateOnlyConverter()
  final DateTime? buyBy;
  final SupplyStatus status;
	@DateOnlyConverter()
  final DateTime? countedFrom;

  Map<String, Object?> toJson() => _$SupplyForecastToJson(this);
}
