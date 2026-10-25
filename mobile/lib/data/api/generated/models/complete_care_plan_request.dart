// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'complete_care_plan_request.g.dart';

@JsonSerializable()
class CompleteCarePlanRequest {
  const CompleteCarePlanRequest({
    required this.performedOn,
    required this.performedTime,
    required this.product,
    required this.manufacturer,
    required this.batchNumber,
    required this.validFrom,
    required this.validUntil,
    required this.clinic,
    required this.veterinarian,
    required this.notes,
    required this.nextDueOn,
    required this.requestId,
  });
  
  factory CompleteCarePlanRequest.fromJson(Map<String, Object?> json) => _$CompleteCarePlanRequestFromJson(json);
  
	@RequiredDateOnlyConverter()
  final DateTime performedOn;
  final String? performedTime;
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
	@DateOnlyConverter()
  final DateTime? validFrom;
	@DateOnlyConverter()
  final DateTime? validUntil;
  final String? clinic;
  final String? veterinarian;
  final String? notes;
	@DateOnlyConverter()
  final DateTime? nextDueOn;
  final String? requestId;

  Map<String, Object?> toJson() => _$CompleteCarePlanRequestToJson(this);
}
