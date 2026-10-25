// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'appointment_status.dart';
import 'appointment_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'appointment_request.g.dart';

@JsonSerializable()
class AppointmentRequest {
  const AppointmentRequest({
    required this.type,
    required this.title,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.location,
    required this.notes,
    required this.petIds,
    required this.remindOffsetsMinutes,
    required this.status,
    required this.requestId,
  });
  
  factory AppointmentRequest.fromJson(Map<String, Object?> json) => _$AppointmentRequestFromJson(json);
  
  final AppointmentType type;
  final String title;
	@RequiredDateOnlyConverter()
  final DateTime date;
  final String time;
  final int? durationMinutes;
  final String? location;
  final String? notes;
  final List<String> petIds;
  final List<int>? remindOffsetsMinutes;
  final AppointmentStatus? status;
  final String? requestId;

  Map<String, Object?> toJson() => _$AppointmentRequestToJson(this);
}
