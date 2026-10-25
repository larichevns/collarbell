// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'appointment_type.dart';
import 'today_pet.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'today_appointment_item.g.dart';

@JsonSerializable()
class TodayAppointmentItem {
  const TodayAppointmentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.time,
    required this.startsAt,
    required this.daysAway,
    required this.location,
    required this.pets,
  });
  
  factory TodayAppointmentItem.fromJson(Map<String, Object?> json) => _$TodayAppointmentItemFromJson(json);
  
  final String id;
  final AppointmentType type;
  final String title;
	@RequiredDateOnlyConverter()
  final DateTime date;
  final String time;
	@RequiredDateOnlyConverter()
  final DateTime startsAt;
  final int daysAway;
  final String? location;
  final List<TodayPet> pets;

  Map<String, Object?> toJson() => _$TodayAppointmentItemToJson(this);
}
