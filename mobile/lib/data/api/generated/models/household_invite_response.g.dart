// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_invite_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdInviteResponse _$HouseholdInviteResponseFromJson(
  Map<String, dynamic> json,
) => HouseholdInviteResponse(
  id: json['id'] as String,
  code: json['code'] as String,
  role: HouseholdRole.fromJson(json['role']),
  createdAt: const RequiredDateOnlyConverter().fromJson(
    json['createdAt'] as String,
  ),
  expiresAt: const RequiredDateOnlyConverter().fromJson(
    json['expiresAt'] as String,
  ),
);

Map<String, dynamic> _$HouseholdInviteResponseToJson(
  HouseholdInviteResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'code': instance.code,
  'role': _$HouseholdRoleEnumMap[instance.role]!,
  'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
  'expiresAt': const RequiredDateOnlyConverter().toJson(instance.expiresAt),
};

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
