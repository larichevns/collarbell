// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentRequest _$AppointmentRequestFromJson(Map<String, dynamic> json) =>
    AppointmentRequest(
      type: AppointmentType.fromJson(json['type']),
      title: json['title'] as String,
      date: const RequiredDateOnlyConverter().fromJson(json['date'] as String),
      time: json['time'] as String,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      petIds: (json['petIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      remindOffsetsMinutes: (json['remindOffsetsMinutes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      status: json['status'] == null
          ? null
          : AppointmentStatus.fromJson(json['status']),
      requestId: json['requestId'] as String?,
    );

Map<String, dynamic> _$AppointmentRequestToJson(AppointmentRequest instance) =>
    <String, dynamic>{
      'type': _$AppointmentTypeEnumMap[instance.type]!,
      'title': instance.title,
      'date': const RequiredDateOnlyConverter().toJson(instance.date),
      'time': instance.time,
      'durationMinutes': instance.durationMinutes,
      'location': instance.location,
      'notes': instance.notes,
      'petIds': instance.petIds,
      'remindOffsetsMinutes': instance.remindOffsetsMinutes,
      'status': _$AppointmentStatusEnumMap[instance.status],
      'requestId': instance.requestId,
    };

const _$AppointmentTypeEnumMap = {
  AppointmentType.vet: 'Vet',
  AppointmentType.grooming: 'Grooming',
  AppointmentType.training: 'Training',
  AppointmentType.other: 'Other',
  AppointmentType.$unknown: r'$unknown',
};

const _$AppointmentStatusEnumMap = {
  AppointmentStatus.planned: 'Planned',
  AppointmentStatus.done: 'Done',
  AppointmentStatus.cancelled: 'Cancelled',
  AppointmentStatus.$unknown: r'$unknown',
};
