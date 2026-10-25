// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_me_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateMeRequest _$UpdateMeRequestFromJson(Map<String, dynamic> json) =>
    UpdateMeRequest(
      displayName: json['displayName'] as String?,
      locale: json['locale'] as String?,
      timeZone: json['timeZone'] as String?,
    );

Map<String, dynamic> _$UpdateMeRequestToJson(UpdateMeRequest instance) =>
    <String, dynamic>{
      'displayName': instance.displayName,
      'locale': instance.locale,
      'timeZone': instance.timeZone,
    };
