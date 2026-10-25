// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'care_status.dart';
import 'interval_unit.dart';
import 'vaccine_target.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'care_plan_response.g.dart';

@JsonSerializable()
class CarePlanResponse {
  const CarePlanResponse({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.intervalValue,
    required this.intervalUnit,
    required this.nextDueOn,
    required this.status,
    required this.daysLeft,
    required this.lastDoneOn,
    required this.remindOffsetsDays,
    required this.defaultProduct,
    required this.targets,
    required this.presetCode,
    required this.notes,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory CarePlanResponse.fromJson(Map<String, Object?> json) => _$CarePlanResponseFromJson(json);
  
  final String id;
  final String petId;
  final CareKind kind;
  final String title;
  final int? intervalValue;
  final IntervalUnit? intervalUnit;
	@RequiredDateOnlyConverter()
  final DateTime nextDueOn;
  final CareStatus status;
  final int daysLeft;
	@DateOnlyConverter()
  final DateTime? lastDoneOn;
  final List<int> remindOffsetsDays;
  final String? defaultProduct;
  final List<VaccineTarget> targets;
  final String? presetCode;
  final String? notes;
  final bool active;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$CarePlanResponseToJson(this);
}
