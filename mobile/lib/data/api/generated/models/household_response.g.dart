// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdResponse _$HouseholdResponseFromJson(Map<String, dynamic> json) =>
    HouseholdResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      timeZone: json['timeZone'] as String,
      role: HouseholdRole.fromJson(json['role']),
    );

Map<String, dynamic> _$HouseholdResponseToJson(HouseholdResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'timeZone': instance.timeZone,
      'role': _$HouseholdRoleEnumMap[instance.role]!,
    };

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
