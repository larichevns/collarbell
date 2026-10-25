// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdDetails _$HouseholdDetailsFromJson(
  Map<String, dynamic> json,
) => HouseholdDetails(
  id: json['id'] as String,
  name: json['name'] as String,
  timeZone: json['timeZone'] as String,
  timeZoneSetByHand: json['timeZoneSetByHand'] as bool,
  role: HouseholdRole.fromJson(json['role']),
  members: (json['members'] as List<dynamic>)
      .map((e) => HouseholdMemberResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  invites: (json['invites'] as List<dynamic>)
      .map((e) => HouseholdInviteResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$HouseholdDetailsToJson(HouseholdDetails instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'timeZone': instance.timeZone,
      'timeZoneSetByHand': instance.timeZoneSetByHand,
      'role': _$HouseholdRoleEnumMap[instance.role]!,
      'members': instance.members.map((e) => e.toJson()).toList(),
      'invites': instance.invites.map((e) => e.toJson()).toList(),
    };

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
