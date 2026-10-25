// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';

part 'complete_appointment_request.g.dart';

@JsonSerializable()
class CompleteAppointmentRequest {
  const CompleteAppointmentRequest({
    required this.recordKind,
    required this.planIds,
    required this.notes,
  });
  
  factory CompleteAppointmentRequest.fromJson(Map<String, Object?> json) => _$CompleteAppointmentRequestFromJson(json);
  
  final CareKind? recordKind;
  final List<String>? planIds;
  final String? notes;

  Map<String, Object?> toJson() => _$CompleteAppointmentRequestToJson(this);
}
