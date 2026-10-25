// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_appointment_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteAppointmentRequest _$CompleteAppointmentRequestFromJson(
  Map<String, dynamic> json,
) => CompleteAppointmentRequest(
  recordKind: json['recordKind'] == null
      ? null
      : CareKind.fromJson(json['recordKind']),
  planIds: (json['planIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$CompleteAppointmentRequestToJson(
  CompleteAppointmentRequest instance,
) => <String, dynamic>{
  'recordKind': _$CareKindEnumMap[instance.recordKind],
  'planIds': instance.planIds,
  'notes': instance.notes,
};

const _$CareKindEnumMap = {
  CareKind.vaccination: 'Vaccination',
  CareKind.rabiesTiter: 'RabiesTiter',
  CareKind.deworming: 'Deworming',
  CareKind.echinococcus: 'Echinococcus',
  CareKind.fleaTick: 'FleaTick',
  CareKind.heartworm: 'Heartworm',
  CareKind.vetExam: 'VetExam',
  CareKind.dental: 'Dental',
  CareKind.grooming: 'Grooming',
  CareKind.procedure: 'Procedure',
  CareKind.other: 'Other',
  CareKind.$unknown: r'$unknown',
};
