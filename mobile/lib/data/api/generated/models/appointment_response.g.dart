// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentResponse _$AppointmentResponseFromJson(Map<String, dynamic> json) =>
    AppointmentResponse(
      id: json['id'] as String,
      type: AppointmentType.fromJson(json['type']),
      title: json['title'] as String,
      date: const RequiredDateOnlyConverter().fromJson(json['date'] as String),
      time: json['time'] as String,
      startsAt: const RequiredDateOnlyConverter().fromJson(
        json['startsAt'] as String,
      ),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      petIds: (json['petIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      remindOffsetsMinutes: (json['remindOffsetsMinutes'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      status: AppointmentStatus.fromJson(json['status']),
      recordIds: (json['recordIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: const RequiredDateOnlyConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: const RequiredDateOnlyConverter().fromJson(
        json['updatedAt'] as String,
      ),
    );

Map<String, dynamic> _$AppointmentResponseToJson(
  AppointmentResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$AppointmentTypeEnumMap[instance.type]!,
  'title': instance.title,
  'date': const RequiredDateOnlyConverter().toJson(instance.date),
  'time': instance.time,
  'startsAt': const RequiredDateOnlyConverter().toJson(instance.startsAt),
  'durationMinutes': instance.durationMinutes,
  'location': instance.location,
  'notes': instance.notes,
  'petIds': instance.petIds,
  'remindOffsetsMinutes': instance.remindOffsetsMinutes,
  'status': _$AppointmentStatusEnumMap[instance.status]!,
  'recordIds': instance.recordIds,
  'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
  'updatedAt': const RequiredDateOnlyConverter().toJson(instance.updatedAt),
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
