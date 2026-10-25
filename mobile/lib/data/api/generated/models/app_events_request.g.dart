// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_events_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppEventsRequest _$AppEventsRequestFromJson(Map<String, dynamic> json) =>
    AppEventsRequest(
      session: json['session'] as String,
      appVersion: json['appVersion'] as String?,
      events: (json['events'] as List<dynamic>?)
          ?.map((e) => AppEventRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AppEventsRequestToJson(AppEventsRequest instance) =>
    <String, dynamic>{
      'session': instance.session,
      'appVersion': instance.appVersion,
      'events': instance.events?.map((e) => e.toJson()).toList(),
    };
