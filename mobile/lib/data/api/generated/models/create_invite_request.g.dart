// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_invite_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateInviteRequest _$CreateInviteRequestFromJson(Map<String, dynamic> json) =>
    CreateInviteRequest(role: HouseholdRole.fromJson(json['role']));

Map<String, dynamic> _$CreateInviteRequestToJson(
  CreateInviteRequest instance,
) => <String, dynamic>{'role': _$HouseholdRoleEnumMap[instance.role]!};

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
