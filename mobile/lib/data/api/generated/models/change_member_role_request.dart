// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

part 'change_member_role_request.g.dart';

@JsonSerializable()
class ChangeMemberRoleRequest {
  const ChangeMemberRoleRequest({
    required this.role,
  });
  
  factory ChangeMemberRoleRequest.fromJson(Map<String, Object?> json) => _$ChangeMemberRoleRequestFromJson(json);
  
  final HouseholdRole role;

  Map<String, Object?> toJson() => _$ChangeMemberRoleRequestToJson(this);
}
