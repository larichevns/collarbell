// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'portion_unit.dart';

part 'supply_feeding_response.g.dart';

@JsonSerializable()
class SupplyFeedingResponse {
  const SupplyFeedingResponse({
    required this.routineId,
    required this.petId,
    required this.petName,
    required this.amount,
    required this.unit,
    required this.timesPerDay,
    required this.counted,
  });
  
  factory SupplyFeedingResponse.fromJson(Map<String, Object?> json) => _$SupplyFeedingResponseFromJson(json);
  
  final String routineId;
  final String petId;
  final String petName;
  final double? amount;
  final PortionUnit? unit;
  final double timesPerDay;
  final bool counted;

  Map<String, Object?> toJson() => _$SupplyFeedingResponseToJson(this);
}
