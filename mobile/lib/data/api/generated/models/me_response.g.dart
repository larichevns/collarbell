// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MeResponse _$MeResponseFromJson(Map<String, dynamic> json) => MeResponse(
  id: json['id'] as String,
  email: json['email'] as String?,
  displayName: json['displayName'] as String?,
  locale: json['locale'] as String,
  timeZone: json['timeZone'] as String,
  household: HouseholdResponse.fromJson(
    json['household'] as Map<String, dynamic>,
  ),
  households: (json['households'] as List<dynamic>)
      .map((e) => HouseholdSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MeResponseToJson(MeResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'locale': instance.locale,
      'timeZone': instance.timeZone,
      'household': instance.household.toJson(),
      'households': instance.households.map((e) => e.toJson()).toList(),
    };
