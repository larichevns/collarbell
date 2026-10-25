// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_notification_settings_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateNotificationSettingsRequest _$UpdateNotificationSettingsRequestFromJson(
  Map<String, dynamic> json,
) => UpdateNotificationSettingsRequest(
  categories: (json['categories'] as List<dynamic>)
      .map(
        (e) => NotificationCategorySetting.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$UpdateNotificationSettingsRequestToJson(
  UpdateNotificationSettingsRequest instance,
) => <String, dynamic>{
  'categories': instance.categories.map((e) => e.toJson()).toList(),
};
