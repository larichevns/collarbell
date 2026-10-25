// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'household_member_response.g.dart';

@JsonSerializable()
class HouseholdMemberResponse {
  const HouseholdMemberResponse({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.isMe,
  });
  
  factory HouseholdMemberResponse.fromJson(Map<String, Object?> json) => _$HouseholdMemberResponseFromJson(json);
  
  final String userId;
  final String? displayName;
  final String? email;
  final HouseholdRole role;
	@RequiredDateOnlyConverter()
  final DateTime joinedAt;
  final bool isMe;

  Map<String, Object?> toJson() => _$HouseholdMemberResponseToJson(this);
}
