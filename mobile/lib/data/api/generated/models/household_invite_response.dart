// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'household_invite_response.g.dart';

@JsonSerializable()
class HouseholdInviteResponse {
  const HouseholdInviteResponse({
    required this.id,
    required this.code,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });
  
  factory HouseholdInviteResponse.fromJson(Map<String, Object?> json) => _$HouseholdInviteResponseFromJson(json);
  
  final String id;
  final String code;
  final HouseholdRole role;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime expiresAt;

  Map<String, Object?> toJson() => _$HouseholdInviteResponseToJson(this);
}
