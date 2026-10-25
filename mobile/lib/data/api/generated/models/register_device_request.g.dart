// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_device_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterDeviceRequest _$RegisterDeviceRequestFromJson(
  Map<String, dynamic> json,
) => RegisterDeviceRequest(
  platform: DevicePlatform.fromJson(json['platform']),
  token: json['token'] as String,
  appVersion: json['appVersion'] as String?,
);

Map<String, dynamic> _$RegisterDeviceRequestToJson(
  RegisterDeviceRequest instance,
) => <String, dynamic>{
  'platform': _$DevicePlatformEnumMap[instance.platform]!,
  'token': instance.token,
  'appVersion': instance.appVersion,
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.android: 'Android',
  DevicePlatform.ios: 'Ios',
  DevicePlatform.$unknown: r'$unknown',
};
