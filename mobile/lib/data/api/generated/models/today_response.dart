// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'today_appointment_item.dart';
import 'today_care_item.dart';
import 'today_feeding_item.dart';
import 'today_supply_item.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'today_response.g.dart';

@JsonSerializable()
class TodayResponse {
  const TodayResponse({
    required this.date,
    required this.feedings,
    required this.appointments,
    required this.care,
    required this.shopping,
  });
  
  factory TodayResponse.fromJson(Map<String, Object?> json) => _$TodayResponseFromJson(json);
  
	@RequiredDateOnlyConverter()
  final DateTime date;
  final List<TodayFeedingItem> feedings;
  final List<TodayAppointmentItem> appointments;
  final List<TodayCareItem> care;
  final List<TodaySupplyItem> shopping;

  Map<String, Object?> toJson() => _$TodayResponseToJson(this);
}
