// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationSettingsResponse _$NotificationSettingsResponseFromJson(
  Map<String, dynamic> json,
) => NotificationSettingsResponse(
  pushReady: json['pushReady'] as bool,
  categories: (json['categories'] as List<dynamic>)
      .map(
        (e) => NotificationCategorySetting.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  devices: (json['devices'] as List<dynamic>)
      .map((e) => DeviceResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$NotificationSettingsResponseToJson(
  NotificationSettingsResponse instance,
) => <String, dynamic>{
  'pushReady': instance.pushReady,
  'categories': instance.categories.map((e) => e.toJson()).toList(),
  'devices': instance.devices.map((e) => e.toJson()).toList(),
};
