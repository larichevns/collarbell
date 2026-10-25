// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'supply_category.dart';
import 'supply_data_source.dart';
import 'supply_unit.dart';
import 'supply_usage_mode.dart';

part 'supply_request.g.dart';

@JsonSerializable()
class SupplyRequest {
  const SupplyRequest({
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
    required this.initialStock,
    required this.dataSource,
    required this.requestId,
  });
  
  factory SupplyRequest.fromJson(Map<String, Object?> json) => _$SupplyRequestFromJson(json);
  
  final String name;
  final String? brand;
  final String? barcode;
  final SupplyCategory category;
  final SupplyUnit unit;
  final double packageSize;
  final int? kcalPerKg;
  final SupplyUsageMode? usageMode;
  final double? manualDailyUsage;
  final int? leadTimeDays;
  final String? storeUrl;
  final String? notes;
  final bool? active;
  final double? initialStock;
  final SupplyDataSource? dataSource;
  final String? requestId;

  Map<String, Object?> toJson() => _$SupplyRequestToJson(this);
}
