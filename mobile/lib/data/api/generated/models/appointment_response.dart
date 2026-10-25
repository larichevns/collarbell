// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'appointment_status.dart';
import 'appointment_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'appointment_response.g.dart';

@JsonSerializable()
class AppointmentResponse {
  const AppointmentResponse({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.time,
    required this.startsAt,
    required this.durationMinutes,
    required this.location,
    required this.notes,
    required this.petIds,
    required this.remindOffsetsMinutes,
    required this.status,
    required this.recordIds,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory AppointmentResponse.fromJson(Map<String, Object?> json) => _$AppointmentResponseFromJson(json);
  
  final String id;
  final AppointmentType type;
  final String title;
	@RequiredDateOnlyConverter()
  final DateTime date;
  final String time;
	@RequiredDateOnlyConverter()
  final DateTime startsAt;
  final int? durationMinutes;
  final String? location;
  final String? notes;
  final List<String> petIds;
  final List<int> remindOffsetsMinutes;
  final AppointmentStatus status;
  final List<String> recordIds;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$AppointmentResponseToJson(this);
}
