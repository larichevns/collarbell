// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'app_event_request.dart';

part 'app_events_request.g.dart';

@JsonSerializable()
class AppEventsRequest {
  const AppEventsRequest({
    required this.session,
    required this.appVersion,
    required this.events,
  });
  
  factory AppEventsRequest.fromJson(Map<String, Object?> json) => _$AppEventsRequestFromJson(json);
  
  final String session;
  final String? appVersion;
  final List<AppEventRequest>? events;

  Map<String, Object?> toJson() => _$AppEventsRequestToJson(this);
}
