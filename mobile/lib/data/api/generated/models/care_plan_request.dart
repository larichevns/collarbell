// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'interval_unit.dart';
import 'vaccine_target.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'care_plan_request.g.dart';

@JsonSerializable()
class CarePlanRequest {
  const CarePlanRequest({
    required this.kind,
    required this.title,
    required this.intervalValue,
    required this.intervalUnit,
    required this.nextDueOn,
    required this.remindOffsetsDays,
    required this.defaultProduct,
    required this.targets,
    required this.presetCode,
    required this.notes,
    required this.active,
    required this.requestId,
  });
  
  factory CarePlanRequest.fromJson(Map<String, Object?> json) => _$CarePlanRequestFromJson(json);
  
  final CareKind kind;
  final String title;
  final int? intervalValue;
  final IntervalUnit? intervalUnit;
	@RequiredDateOnlyConverter()
  final DateTime nextDueOn;
  final List<int>? remindOffsetsDays;
  final String? defaultProduct;
  final List<VaccineTarget>? targets;
  final String? presetCode;
  final String? notes;
  final bool? active;
  final String? requestId;

  Map<String, Object?> toJson() => _$CarePlanRequestToJson(this);
}
