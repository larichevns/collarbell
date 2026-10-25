// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodayResponse _$TodayResponseFromJson(Map<String, dynamic> json) =>
    TodayResponse(
      date: const RequiredDateOnlyConverter().fromJson(json['date'] as String),
      feedings: (json['feedings'] as List<dynamic>)
          .map((e) => TodayFeedingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      appointments: (json['appointments'] as List<dynamic>)
          .map((e) => TodayAppointmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      care: (json['care'] as List<dynamic>)
          .map((e) => TodayCareItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      shopping: (json['shopping'] as List<dynamic>)
          .map((e) => TodaySupplyItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TodayResponseToJson(TodayResponse instance) =>
    <String, dynamic>{
      'date': const RequiredDateOnlyConverter().toJson(instance.date),
      'feedings': instance.feedings.map((e) => e.toJson()).toList(),
      'appointments': instance.appointments.map((e) => e.toJson()).toList(),
      'care': instance.care.map((e) => e.toJson()).toList(),
      'shopping': instance.shopping.map((e) => e.toJson()).toList(),
    };
