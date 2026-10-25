// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_deletion_outcome.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdDeletionOutcome _$HouseholdDeletionOutcomeFromJson(
  Map<String, dynamic> json,
) => HouseholdDeletionOutcome(
  id: json['id'] as String,
  name: json['name'] as String,
  role: HouseholdRole.fromJson(json['role']),
  fate: HouseholdFate.fromJson(json['fate']),
  pets: (json['pets'] as num).toInt(),
  others: (json['others'] as num).toInt(),
  newOwner: json['newOwner'] as String?,
);

Map<String, dynamic> _$HouseholdDeletionOutcomeToJson(
  HouseholdDeletionOutcome instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'role': _$HouseholdRoleEnumMap[instance.role]!,
  'fate': _$HouseholdFateEnumMap[instance.fate]!,
  'pets': instance.pets,
  'others': instance.others,
  'newOwner': instance.newOwner,
};

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};

const _$HouseholdFateEnumMap = {
  HouseholdFate.deleted: 'Deleted',
  HouseholdFate.kept: 'Kept',
  HouseholdFate.handedOver: 'HandedOver',
  HouseholdFate.$unknown: r'$unknown',
};
