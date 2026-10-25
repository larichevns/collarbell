// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_member_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdMemberResponse _$HouseholdMemberResponseFromJson(
  Map<String, dynamic> json,
) => HouseholdMemberResponse(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String?,
  email: json['email'] as String?,
  role: HouseholdRole.fromJson(json['role']),
  joinedAt: const RequiredDateOnlyConverter().fromJson(
    json['joinedAt'] as String,
  ),
  isMe: json['isMe'] as bool,
);

Map<String, dynamic> _$HouseholdMemberResponseToJson(
  HouseholdMemberResponse instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'displayName': instance.displayName,
  'email': instance.email,
  'role': _$HouseholdRoleEnumMap[instance.role]!,
  'joinedAt': const RequiredDateOnlyConverter().toJson(instance.joinedAt),
  'isMe': instance.isMe,
};

const _$HouseholdRoleEnumMap = {
  HouseholdRole.owner: 'Owner',
  HouseholdRole.member: 'Member',
  HouseholdRole.helper: 'Helper',
  HouseholdRole.$unknown: r'$unknown',
};
