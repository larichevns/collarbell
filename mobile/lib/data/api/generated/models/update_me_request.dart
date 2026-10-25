// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_me_request.g.dart';

@JsonSerializable()
class UpdateMeRequest {
  const UpdateMeRequest({
    required this.displayName,
    required this.locale,
    required this.timeZone,
  });
  
  factory UpdateMeRequest.fromJson(Map<String, Object?> json) => _$UpdateMeRequestFromJson(json);
  
  final String? displayName;
  final String? locale;
  final String? timeZone;

  Map<String, Object?> toJson() => _$UpdateMeRequestToJson(this);
}
