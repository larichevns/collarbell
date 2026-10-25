// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_event_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppEventRequest _$AppEventRequestFromJson(Map<String, dynamic> json) =>
    AppEventRequest(
      atUnixMs: (json['atUnixMs'] as num).toInt(),
      kind: AppEventKind.fromJson(json['kind']),
      name: json['name'] as String?,
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$AppEventRequestToJson(AppEventRequest instance) =>
    <String, dynamic>{
      'atUnixMs': instance.atUnixMs,
      'kind': _$AppEventKindEnumMap[instance.kind]!,
      'name': instance.name,
      'detail': instance.detail,
    };

const _$AppEventKindEnumMap = {
  AppEventKind.screen: 'Screen',
  AppEventKind.action: 'Action',
  AppEventKind.error: 'Error',
  AppEventKind.crash: 'Crash',
  AppEventKind.$unknown: r'$unknown',
};
