// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'supply_category.dart';
import 'supply_feeding_response.dart';
import 'supply_forecast.dart';
import 'supply_unit.dart';
import 'supply_usage_mode.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'supply_response.g.dart';

@JsonSerializable()
class SupplyResponse {
  const SupplyResponse({
    required this.id,
    required this.name,
    required this.brand,
    required this.barcode,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.kcalPerKg,
    required this.usageMode,
    required this.manualDailyUsage,
    required this.leadTimeDays,
    required this.storeUrl,
    required this.notes,
    required this.active,
    required this.forecast,
    required this.feedings,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory SupplyResponse.fromJson(Map<String, Object?> json) => _$SupplyResponseFromJson(json);
  
  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final SupplyCategory category;
  final SupplyUnit unit;
  final double packageSize;
  final int? kcalPerKg;
  final SupplyUsageMode usageMode;
  final double? manualDailyUsage;
  final int leadTimeDays;
  final String? storeUrl;
  final String? notes;
  final bool active;
  final SupplyForecast forecast;
  final List<SupplyFeedingResponse> feedings;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$SupplyResponseToJson(this);
}
