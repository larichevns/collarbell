// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_member_role_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangeMemberRoleRequest _$ChangeMemberRoleRequestFromJson(
  Map<String, dynamic> json,
) => ChangeMemberRoleRequest(role: HouseholdRole.fromJson(json['role']));

Map<String, dynamic> _$ChangeMemberRoleRequestToJson(
  ChangeMemberRoleRequest instance,
) => <String, dynamic>{'role': _$HouseholdRoleEnumMap[instance.role]!};

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
