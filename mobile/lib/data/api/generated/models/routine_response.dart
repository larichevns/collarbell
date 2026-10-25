// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'day_of_week.dart';
import 'portion_unit.dart';
import 'routine_kind.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'routine_response.g.dart';

@JsonSerializable()
class RoutineResponse {
  const RoutineResponse({
    required this.id,
    required this.petId,
    required this.kind,
    required this.times,
    required this.days,
    required this.food,
    required this.amount,
    required this.unit,
    required this.notes,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.supplyItemId,
  });
  
  factory RoutineResponse.fromJson(Map<String, Object?> json) => _$RoutineResponseFromJson(json);
  
  final String id;
  final String petId;
  final RoutineKind kind;
  final List<String> times;
  final List<DayOfWeek> days;
  final String? food;
  final double? amount;
  final PortionUnit? unit;
  final String? notes;
  final bool active;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;
  final String? supplyItemId;

  Map<String, Object?> toJson() => _$RoutineResponseToJson(this);
}
