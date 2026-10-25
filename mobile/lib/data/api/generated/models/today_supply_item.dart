// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'supply_category.dart';
import 'supply_status.dart';
import 'supply_unit.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'today_supply_item.g.dart';

@JsonSerializable()
class TodaySupplyItem {
  const TodaySupplyItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.status,
    required this.remaining,
    required this.daysLeft,
    required this.runsOutOn,
  });
  
  factory TodaySupplyItem.fromJson(Map<String, Object?> json) => _$TodaySupplyItemFromJson(json);
  
  final String id;
  final String name;
  final String? brand;
  final SupplyCategory category;
  final SupplyUnit unit;
  final double packageSize;
  final SupplyStatus status;
  final double? remaining;
  final double? daysLeft;
	@DateOnlyConverter()
  final DateTime? runsOutOn;

  Map<String, Object?> toJson() => _$TodaySupplyItemToJson(this);
}
