// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_appointment_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteAppointmentResponse _$CompleteAppointmentResponseFromJson(
  Map<String, dynamic> json,
) => CompleteAppointmentResponse(
  appointment: AppointmentResponse.fromJson(
    json['appointment'] as Map<String, dynamic>,
  ),
  movedPlanIds: (json['movedPlanIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$CompleteAppointmentResponseToJson(
  CompleteAppointmentResponse instance,
) => <String, dynamic>{
  'appointment': instance.appointment.toJson(),
  'movedPlanIds': instance.movedPlanIds,
};
