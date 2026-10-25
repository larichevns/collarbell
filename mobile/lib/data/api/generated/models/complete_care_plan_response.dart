// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_plan_response.dart';
import 'care_record_response.dart';

part 'complete_care_plan_response.g.dart';

@JsonSerializable()
class CompleteCarePlanResponse {
  const CompleteCarePlanResponse({
    required this.plan,
    required this.record,
  });
  
  factory CompleteCarePlanResponse.fromJson(Map<String, Object?> json) => _$CompleteCarePlanResponseFromJson(json);
  
  final CarePlanResponse plan;
  final CareRecordResponse record;

  Map<String, Object?> toJson() => _$CompleteCarePlanResponseToJson(this);
}
