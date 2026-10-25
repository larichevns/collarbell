// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdSummary _$HouseholdSummaryFromJson(Map<String, dynamic> json) =>
    HouseholdSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      role: HouseholdRole.fromJson(json['role']),
      timeZone: json['timeZone'] as String,
      memberCount: (json['memberCount'] as num).toInt(),
    );

Map<String, dynamic> _$HouseholdSummaryToJson(HouseholdSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': _$HouseholdRoleEnumMap[instance.role]!,
      'timeZone': instance.timeZone,
      'memberCount': instance.memberCount,
    };

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
