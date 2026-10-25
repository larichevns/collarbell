// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceResponse _$DeviceResponseFromJson(Map<String, dynamic> json) =>
    DeviceResponse(
      id: json['id'] as String,
      platform: DevicePlatform.fromJson(json['platform']),
      appVersion: json['appVersion'] as String?,
      lastSeenAt: const RequiredDateOnlyConverter().fromJson(
        json['lastSeenAt'] as String,
      ),
    );

Map<String, dynamic> _$DeviceResponseToJson(
  DeviceResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'platform': _$DevicePlatformEnumMap[instance.platform]!,
  'appVersion': instance.appVersion,
  'lastSeenAt': const RequiredDateOnlyConverter().toJson(instance.lastSeenAt),
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.android: 'Android',
  DevicePlatform.ios: 'Ios',
  DevicePlatform.$unknown: r'$unknown',
};
