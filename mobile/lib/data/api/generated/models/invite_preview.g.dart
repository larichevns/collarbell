// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvitePreview _$InvitePreviewFromJson(Map<String, dynamic> json) =>
    InvitePreview(
      householdName: json['householdName'] as String,
      invitedBy: json['invitedBy'] as String?,
      role: HouseholdRole.fromJson(json['role']),
      expiresAt: const RequiredDateOnlyConverter().fromJson(
        json['expiresAt'] as String,
      ),
      alreadyMember: json['alreadyMember'] as bool,
    );

Map<String, dynamic> _$InvitePreviewToJson(InvitePreview instance) =>
    <String, dynamic>{
      'householdName': instance.householdName,
      'invitedBy': instance.invitedBy,
      'role': _$HouseholdRoleEnumMap[instance.role]!,
      'expiresAt': const RequiredDateOnlyConverter().toJson(instance.expiresAt),
      'alreadyMember': instance.alreadyMember,
    };

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
