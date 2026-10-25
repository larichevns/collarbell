// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_response.dart';
import 'notification_category_setting.dart';

part 'notification_settings_response.g.dart';

@JsonSerializable()
class NotificationSettingsResponse {
  const NotificationSettingsResponse({
    required this.pushReady,
    required this.categories,
    required this.devices,
  });
  
  factory NotificationSettingsResponse.fromJson(Map<String, Object?> json) => _$NotificationSettingsResponseFromJson(json);
  
  final bool pushReady;
  final List<NotificationCategorySetting> categories;
  final List<DeviceResponse> devices;

  Map<String, Object?> toJson() => _$NotificationSettingsResponseToJson(this);
}
