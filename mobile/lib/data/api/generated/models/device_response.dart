// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_platform.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'device_response.g.dart';

@JsonSerializable()
class DeviceResponse {
  const DeviceResponse({
    required this.id,
    required this.platform,
    required this.appVersion,
    required this.lastSeenAt,
  });
  
  factory DeviceResponse.fromJson(Map<String, Object?> json) => _$DeviceResponseFromJson(json);
  
  final String id;
  final DevicePlatform platform;
  final String? appVersion;
	@RequiredDateOnlyConverter()
  final DateTime lastSeenAt;

  Map<String, Object?> toJson() => _$DeviceResponseToJson(this);
}
