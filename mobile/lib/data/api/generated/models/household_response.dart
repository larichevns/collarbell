// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

part 'household_response.g.dart';

@JsonSerializable()
class HouseholdResponse {
  const HouseholdResponse({
    required this.id,
    required this.name,
    required this.timeZone,
    required this.role,
  });
  
  factory HouseholdResponse.fromJson(Map<String, Object?> json) => _$HouseholdResponseFromJson(json);
  
  final String id;
  final String name;
  final String timeZone;
  final HouseholdRole role;

  Map<String, Object?> toJson() => _$HouseholdResponseToJson(this);
}
