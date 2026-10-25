// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

part 'create_invite_request.g.dart';

@JsonSerializable()
class CreateInviteRequest {
  const CreateInviteRequest({
    required this.role,
  });
  
  factory CreateInviteRequest.fromJson(Map<String, Object?> json) => _$CreateInviteRequestFromJson(json);
  
  final HouseholdRole role;

  Map<String, Object?> toJson() => _$CreateInviteRequestToJson(this);
}
