// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'app_event_kind.dart';

part 'app_event_request.g.dart';

@JsonSerializable()
class AppEventRequest {
  const AppEventRequest({
    required this.atUnixMs,
    required this.kind,
    required this.name,
    required this.detail,
  });
  
  factory AppEventRequest.fromJson(Map<String, Object?> json) => _$AppEventRequestFromJson(json);
  
  final int atUnixMs;
  final AppEventKind kind;
  final String? name;
  final String? detail;

  Map<String, Object?> toJson() => _$AppEventRequestToJson(this);
}
