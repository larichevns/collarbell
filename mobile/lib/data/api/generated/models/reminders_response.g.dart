// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RemindersResponse _$RemindersResponseFromJson(Map<String, dynamic> json) =>
    RemindersResponse(
      upcoming: (json['upcoming'] as List<dynamic>)
          .map((e) => ReminderResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent: (json['recent'] as List<dynamic>)
          .map((e) => ReminderResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RemindersResponseToJson(RemindersResponse instance) =>
    <String, dynamic>{
      'upcoming': instance.upcoming.map((e) => e.toJson()).toList(),
      'recent': instance.recent.map((e) => e.toJson()).toList(),
    };
