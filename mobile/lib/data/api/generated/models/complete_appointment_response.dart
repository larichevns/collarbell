// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'appointment_response.dart';

part 'complete_appointment_response.g.dart';

@JsonSerializable()
class CompleteAppointmentResponse {
  const CompleteAppointmentResponse({
    required this.appointment,
    required this.movedPlanIds,
  });
  
  factory CompleteAppointmentResponse.fromJson(Map<String, Object?> json) => _$CompleteAppointmentResponseFromJson(json);
  
  final AppointmentResponse appointment;
  final List<String> movedPlanIds;

  Map<String, Object?> toJson() => _$CompleteAppointmentResponseToJson(this);
}
