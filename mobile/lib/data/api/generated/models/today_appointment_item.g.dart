// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_appointment_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodayAppointmentItem _$TodayAppointmentItemFromJson(
  Map<String, dynamic> json,
) => TodayAppointmentItem(
  id: json['id'] as String,
  type: AppointmentType.fromJson(json['type']),
  title: json['title'] as String,
  date: const RequiredDateOnlyConverter().fromJson(json['date'] as String),
  time: json['time'] as String,
  startsAt: const RequiredDateOnlyConverter().fromJson(
    json['startsAt'] as String,
  ),
  daysAway: (json['daysAway'] as num).toInt(),
  location: json['location'] as String?,
  pets: (json['pets'] as List<dynamic>)
      .map((e) => TodayPet.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TodayAppointmentItemToJson(
  TodayAppointmentItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$AppointmentTypeEnumMap[instance.type]!,
  'title': instance.title,
  'date': const RequiredDateOnlyConverter().toJson(instance.date),
  'time': instance.time,
  'startsAt': const RequiredDateOnlyConverter().toJson(instance.startsAt),
  'daysAway': instance.daysAway,
  'location': instance.location,
  'pets': instance.pets.map((e) => e.toJson()).toList(),
};

const _$AppointmentTypeEnumMap = {
  AppointmentType.vet: 'Vet',
  AppointmentType.grooming: 'Grooming',
  AppointmentType.training: 'Training',
  AppointmentType.other: 'Other',
  AppointmentType.$unknown: r'$unknown',
};
