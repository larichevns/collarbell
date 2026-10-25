// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_household_request.g.dart';

@JsonSerializable()
class UpdateHouseholdRequest {
  const UpdateHouseholdRequest({
    required this.name,
    required this.timeZone,
  });
  
  factory UpdateHouseholdRequest.fromJson(Map<String, Object?> json) => _$UpdateHouseholdRequestFromJson(json);
  
  final String? name;
  final String? timeZone;

  Map<String, Object?> toJson() => _$UpdateHouseholdRequestToJson(this);
}
