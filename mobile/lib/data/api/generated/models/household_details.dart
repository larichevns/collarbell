// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_invite_response.dart';
import 'household_member_response.dart';
import 'household_role.dart';

part 'household_details.g.dart';

@JsonSerializable()
class HouseholdDetails {
  const HouseholdDetails({
    required this.id,
    required this.name,
    required this.timeZone,
    required this.timeZoneSetByHand,
    required this.role,
    required this.members,
    required this.invites,
  });
  
  factory HouseholdDetails.fromJson(Map<String, Object?> json) => _$HouseholdDetailsFromJson(json);
  
  final String id;
  final String name;
  final String timeZone;
  final bool timeZoneSetByHand;
  final HouseholdRole role;
  final List<HouseholdMemberResponse> members;
  final List<HouseholdInviteResponse> invites;

  Map<String, Object?> toJson() => _$HouseholdDetailsToJson(this);
}
