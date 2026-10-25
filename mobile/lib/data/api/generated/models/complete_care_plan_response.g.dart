// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_care_plan_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteCarePlanResponse _$CompleteCarePlanResponseFromJson(
  Map<String, dynamic> json,
) => CompleteCarePlanResponse(
  plan: CarePlanResponse.fromJson(json['plan'] as Map<String, dynamic>),
  record: CareRecordResponse.fromJson(json['record'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CompleteCarePlanResponseToJson(
  CompleteCarePlanResponse instance,
) => <String, dynamic>{
  'plan': instance.plan.toJson(),
  'record': instance.record.toJson(),
};
