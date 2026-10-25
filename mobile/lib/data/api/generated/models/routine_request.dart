// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'day_of_week.dart';
import 'portion_unit.dart';
import 'routine_kind.dart';

part 'routine_request.g.dart';

@JsonSerializable()
class RoutineRequest {
  const RoutineRequest({
    required this.kind,
    required this.times,
    required this.days,
    required this.food,
    required this.amount,
    required this.unit,
    required this.notes,
    required this.active,
    required this.requestId,
    this.supplyItemId,
  });
  
  factory RoutineRequest.fromJson(Map<String, Object?> json) => _$RoutineRequestFromJson(json);
  
  final RoutineKind? kind;
  final List<String> times;
  final List<DayOfWeek>? days;
  final String? food;
  final double? amount;
  final PortionUnit? unit;
  final String? notes;
  final bool? active;
  final String? requestId;
  final String? supplyItemId;

  Map<String, Object?> toJson() => _$RoutineRequestToJson(this);
}
